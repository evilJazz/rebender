export RUNNING_REMOTELY=0
export SYNCED_TO_REMOTE=0

[ "$1" == "--remote" ] && RUNNING_REMOTELY=1 && shift 1

remote_executeCommand()
{
    ssh -t -o ConnectTimeout=300 -o BatchMode=yes -o StrictHostKeyChecking=no -A "$REMOTE_SSH" -- ${REMOTE_RUN_CMD[@]} "$@"
}

remote_isRequested()
{
    [[ -n "$REMOTE_SSH" ]] && [[ $RUNNING_REMOTELY -eq 0 ]]
}

remote_pushAppConfig()
{
    [ -z "$REMOTE_INSTALL_DIR" ] && export REMOTE_INSTALL_DIR="/tmp/backup_${RANDOM}_$$"
    
    info "Copying to remote..."
    ssh "$REMOTE_SSH" "mkdir -p \"$REMOTE_INSTALL_DIR\"; chmod 700 \"$REMOTE_INSTALL_DIR\""
    rsync -zrlptD --exclude=".git" "$SCRIPT_ROOT"/ "$REMOTE_SSH:$REMOTE_INSTALL_DIR"/

    if [ "$CONFIG_ROOT" != "$SELFCONTAINED_CONFIG_ROOT" ]; then
        info "Copying external config to remote..."
        rsync -zrlptD --exclude=".git" "$CONFIG_ROOT"/ "$REMOTE_SSH:$REMOTE_INSTALL_DIR"/configs/
    fi

    ssh "$REMOTE_SSH" chmod 700 "$REMOTE_INSTALL_DIR"
    SYNCED_TO_REMOTE=1
}

remote_removeAppConfig()
{
    [[ -n "$REMOTE_INSTALL_KEEP" ]] && [[ "$REMOTE_INSTALL_KEEP" -eq 1 ]] && return 0

    [ -z "$REMOTE_INSTALL_DIR" ] && fatal "REMOTE_INSTALL_DIR not specified or empty." && return 1

    info "Cleaning up remote..."
    ssh "$REMOTE_SSH" rm -Rf "$REMOTE_INSTALL_DIR"
    SYNCED_TO_REMOTE=0
}

remote_run()
{
    if [ "$SYNCED_TO_REMOTE" -ne 1 ]; then
        remote_pushAppConfig
    fi

    SCRIPT_NAME=$(basename "$SCRIPT_FILENAME")
    remote_executeCommand "$REMOTE_INSTALL_DIR/$SCRIPT_NAME" --remote "$@"
}

remote_cleanUp() {
    if [ "$SYNCED_TO_REMOTE" -eq 1 ]; then
        # Clean up on remote...
        remote_removeAppConfig
    fi
}

trap remote_cleanUp EXIT