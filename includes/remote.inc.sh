export RUNNING_REMOTELY=0
export SYNCED_TO_REMOTE=0

[ "$1" == "--remote" ] && RUNNING_REMOTELY=1 && shift 1

executeOnRemote()
{
    ssh -t -o ConnectTimeout=300 -o BatchMode=yes -o StrictHostKeyChecking=no -A "$REMOTE_SSH" -- ${REMOTE_RUN_CMD[@]} "$@"
}

isRemote()
{
    [[ -n "$REMOTE_SSH" ]] && [[ $RUNNING_REMOTELY -eq 0 ]]
}

rsyncAppToRemote()
{
    [ -z "$REMOTE_INSTALL_DIR" ] && export REMOTE_INSTALL_DIR="/tmp/backup_${RANDOM}_$$"
    echo "Copying to remote..."
    ssh "$REMOTE_SSH" "mkdir -p \"$REMOTE_INSTALL_DIR\"; chmod 700 \"$REMOTE_INSTALL_DIR\""
    rsync -zrlptD --exclude=".git" "$SCRIPT_ROOT"/ "$REMOTE_SSH:$REMOTE_INSTALL_DIR"/

    if [ "$CONFIG_ROOT" != "$SELFCONTAINED_CONFIG_ROOT" ]; then
        echo "Copying external config to remote..."
        rsync -zrlptD --exclude=".git" "$CONFIG_ROOT"/ "$REMOTE_SSH:$REMOTE_INSTALL_DIR"/configs/
    fi

    ssh "$REMOTE_SSH" chmod 700 "$REMOTE_INSTALL_DIR"
    SYNCED_TO_REMOTE=1
}

removeAppFromRemote()
{
    [[ -n "$REMOTE_INSTALL_KEEP" ]] && [[ "$REMOTE_INSTALL_KEEP" -eq 1 ]] && return 0

    [ -z "$REMOTE_INSTALL_DIR" ] && echo "REMOTE_INSTALL_DIR is empty. Quitting." && exit 1
    echo "Cleaning up remote..."
    ssh "$REMOTE_SSH" rm -Rf "$REMOTE_INSTALL_DIR"
    SYNCED_TO_REMOTE=0
}

runOnRemote()
{
    if [ "$SYNCED_TO_REMOTE" -ne 1 ]; then
        rsyncAppToRemote
    fi

    SCRIPT_NAME=$(basename "$SCRIPT_FILENAME")
    executeOnRemote "$REMOTE_INSTALL_DIR/$SCRIPT_NAME" --remote "$@"
}

cleanUp() {
    if [ "$SYNCED_TO_REMOTE" -eq 1 ]; then
        # Clean up on remote...
        removeAppFromRemote
    fi
}

trap cleanUp EXIT
