#!/bin/bash
export CONFIG_DIR="$SCRIPT_ROOT/configs"

export RUNNING_REMOTELY=0
export SYNCED_TO_REMOTE=0

[ "$1" == "--remote" ] && RUNNING_REMOTELY=1 && shift 1

functionExists()
{
    declare -f "$1" > /dev/null
}

executeCallback()
{
    functionExists "$1" && "$@"

    if [ "$RUNNING_REMOTELY" -eq 1 ]; then
        REMOTE_CALLBACK_NAME="${1}OnRemote"
        shift 1
        if functionExists "$REMOTE_CALLBACK_NAME"; then
            "$REMOTE_CALLBACK_NAME" "$@"
        fi
    fi
}

executeOnRemote()
{
    ssh -q -o ConnectTimeout=300 -o BatchMode=yes -o StrictHostKeyChecking=no -A "$REMOTE_SOURCE_SSH" -- ${REMOTE_SOURCE_RUN_CMD[@]} "$@"
}

loadConfig()
{
    export CONFIG="$1"
    export CONFIG_FILE="$CONFIG_DIR/$CONFIG.conf.sh"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$CONFIG_FILE does not exist. Aborting!"
        exit 1
    fi

    source "$CONFIG_FILE"
}

sendEMail()
{
    sender=$1
    recipient=$2
    subject=$3
    message=$4

    ( /bin/cat << EOF
From: $sender
To: $recipient
Subject: $subject

$message
EOF
    ) | /usr/sbin/sendmail -t
}

isRemote()
{
    [[ -n "$REMOTE_SOURCE_SSH" ]] && [[ $RUNNING_REMOTELY -eq 0 ]]
}

rsyncAppToRemote()
{
    [ -z "$REMOTE_APP_DIR" ] && export REMOTE_APP_DIR="/tmp/backup_${RANDOM}_$$"
    echo "Copying configuration to remote..."
    ssh "$REMOTE_SOURCE_SSH" "mkdir -p \"$REMOTE_APP_DIR\"; chmod 700 \"$REMOTE_APP_DIR\""
    rsync -zrlptD --exclude=".git" "$SCRIPT_ROOT"/ "$REMOTE_SOURCE_SSH:$REMOTE_APP_DIR"/
    ssh "$REMOTE_SOURCE_SSH" chmod 700 "$REMOTE_APP_DIR"
    SYNCED_TO_REMOTE=1
}

removeAppFromRemote()
{
    [ "$REMOTE_APP_DIR_KEEP" -eq 1 ] && return 0

    [ -z "$REMOTE_APP_DIR" ] && echo "REMOTE_APP_DIR is empty. Quitting." && exit 1
    echo "Cleaning up remote..."
    ssh "$REMOTE_SOURCE_SSH" rm -Rf "$REMOTE_APP_DIR"
    SYNCED_TO_REMOTE=0
}

runOnRemote()
{
    if [ "$SYNCED_TO_REMOTE" -ne 1 ]; then
        rsyncAppToRemote
    fi

    SCRIPT_NAME=$(basename "$SCRIPT_FILENAME")
    executeOnRemote "$REMOTE_APP_DIR/$SCRIPT_NAME" --remote "$@"
}

cleanUp() {
    if [ "$SYNCED_TO_REMOTE" -eq 1 ]; then
        # Clean up on remote...
        removeAppFromRemote
    fi
}

trap cleanUp EXIT
