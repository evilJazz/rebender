REMOTE_INSTALL_USE_SUDO=0
REMOTE_USE_SUDO=0

SSH_AGENT_STARTED_HERE=0
export RUNNING_REMOTELY=0
export SYNCED_TO_REMOTE=0

[ "$1" == "--remote" ] && RUNNING_REMOTELY=1 && shift 1

remote_init()
{
    if [ $RUNNING_REMOTELY -eq 0 ]; then
        if [ -z "$SSH_AGENT_PID" ]; then
            info "Starting SSH agent..."
            eval $(ssh-agent -s) > /dev/null 2>&1
            SSH_AGENT_STARTED_HERE=1
        fi
        
        if [ -d "$CREDS_ROOT" ]; then
            info "Adding credentials to SSH agent..."
            ssh-add "$CREDS_ROOT/"*
        fi
    fi

    if [ $REMOTE_INSTALL_USE_SUDO -eq 1 ]; then
        info "Using sudo on remote SSH to install rebender..."
        REMOTE_INSTALL_SUDO_CMD=(sudo -E)
    else
        REMOTE_INSTALL_SUDO_CMD=()
    fi

    if [ $REMOTE_USE_SUDO -eq 1 ]; then
        info "Using sudo on remote SSH to start rebender..."
        REMOTE_SUDO_CMD=(sudo -E)
    else
        REMOTE_SUDO_CMD=()
    fi
}

remote_ssh()
{
    ssh -t -o ConnectTimeout=300 -o BatchMode=yes -o StrictHostKeyChecking=no -A "$@"
}

remote_executeCommand()
{
    remote_ssh ${REMOTE_SSH_PARAMS[@]} "$REMOTE_SSH" -- ${REMOTE_SUDO_CMD[@]} ${REMOTE_RUN_CMD[@]} "$@"
}

remote_executeInstallCommand()
{
    remote_ssh ${REMOTE_SSH_PARAMS[@]} "$REMOTE_SSH" -- ${REMOTE_INSTALL_SUDO_CMD[@]} ${REMOTE_INSTALL_CMD[@]} "$@"
}

remote_isRequested()
{
    [[ -n "$REMOTE_SSH" ]] && [[ $RUNNING_REMOTELY -eq 0 ]]
}

remote_pushAppConfig()
{
    if [ "$SYNCED_TO_REMOTE" -ne 1 ]; then
        [ -z "$REMOTE_INSTALL_DIR" ] && export REMOTE_INSTALL_DIR="/tmp/backup_${RANDOM}_$$"
        
        info "Copying to remote..."
        remote_executeInstallCommand "mkdir -p \"$REMOTE_INSTALL_DIR\""
        remote_executeInstallCommand "chmod 700 \"$REMOTE_INSTALL_DIR\""
        eval rsync -zrlptD -e \"ssh ${REMOTE_SSH_PARAMS[@]}\" --rsync-path=\"${REMOTE_INSTALL_SUDO_CMD[@]} ${REMOTE_INSTALL_CMD[@]} rsync\" --exclude=".git" "$SCRIPT_ROOT"/ "$REMOTE_SSH:$REMOTE_INSTALL_DIR"/

        if [ "$CONFIG_ROOT" != "$SELFCONTAINED_CONFIG_ROOT" ]; then
            info "Copying external config to remote..."
            eval rsync -zrlptD -e \"ssh ${REMOTE_SSH_PARAMS[@]}\" --rsync-path=\"${REMOTE_INSTALL_SUDO_CMD[@]} ${REMOTE_INSTALL_CMD[@]} rsync\" --exclude=".git" "$CONFIG_ROOT"/ "$REMOTE_SSH:$REMOTE_INSTALL_DIR"/configs/
        fi

        SYNCED_TO_REMOTE=1
    fi
}

remote_removeAppConfig()
{
    [[ -n "$REMOTE_INSTALL_KEEP" ]] && [[ "$REMOTE_INSTALL_KEEP" -eq 1 ]] && return 0

    [ -z "$REMOTE_INSTALL_DIR" ] && fatal "REMOTE_INSTALL_DIR not specified or empty." && return 1

    info "Cleaning up remote..."
    remote_executeInstallCommand rm -Rf "$REMOTE_INSTALL_DIR"
    SYNCED_TO_REMOTE=0
}

remote_run()
{
    remote_pushAppConfig

    SCRIPT_NAME=$(basename "$SCRIPT_FILENAME")
    remote_executeCommand "$REMOTE_INSTALL_DIR/$SCRIPT_NAME" --remote "$@"
}

remote_cleanUp() {
    if [ "$SYNCED_TO_REMOTE" -eq 1 ]; then
        # Clean up on remote...
        remote_removeAppConfig
    fi

    if [ "$SSH_AGENT_STARTED_HERE" -eq 1 ]; then
        ssh-agent -k > /dev/null 2>&1 || true
    fi
}

trap remote_cleanUp EXIT
