#!/bin/bash

SELFCONTAINED_CONFIG_ROOT="$SCRIPT_ROOT/configs"
export CONFIG_ROOT="${REBENDER_CONFIG_DIR:-$SELFCONTAINED_CONFIG_ROOT}"
unset REBENDER_CONFIG_DIR

export RUNNING_REMOTELY=0
export SYNCED_TO_REMOTE=0

[ "$1" == "--remote" ] && RUNNING_REMOTELY=1 && shift 1

tableOutput()
{
    if [ $# -gt 2 ]; then
        printf "%25s  %-25s %25s\n" "$@"
    else
        printf "%25s  %-50s\n" "$@"
    fi
}

functionExists()
{
    declare -f "$1" > /dev/null
}

executeCallback()
{
    if functionExists "$1"; then
        "$@"
    fi

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
    ssh -t -o ConnectTimeout=300 -o BatchMode=yes -o StrictHostKeyChecking=no -A "$REMOTE_SSH" -- ${REMOTE_RUN_CMD[@]} "$@"
}

configList()
{
    find "$CONFIG_ROOT" -maxdepth 1 -mindepth 1 -name "*.conf.sh" -and -not -name "*.template.conf.sh" -type f | sort
}

configUsage()
{
    echo "Available configs:"
    echo
    for config in $(configList); do
        CONFIG_NAME=$(basename "$config")
        CONFIG_NAME=${CONFIG_NAME%.conf.sh}
        tableOutput "$CONFIG_NAME" "$config"
    done
    echo
}

loadConfig()
{
    SPLIT=$(dirname "$1")
    if [ "$SPLIT" != "." ]; then
        export FULL_CONFIG="$1"
        export CONFIG=$SPLIT
        export SUB_CONFIG=$(basename "$1")
    else
        export FULL_CONFIG="$1"
        export CONFIG="$1"
        export SUB_CONFIG=
    fi

    if [ -z "$CONFIG" ]; then
        echo "No config specified. Aborting!"
        return 1
    fi

    export CONFIG_FILE="$CONFIG_ROOT/$CONFIG.conf.sh"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$CONFIG_FILE does not exist. Aborting!"
        return 1
    fi

    source "$CONFIG_FILE"

    if [ -n "$SUB_CONFIG" ]; then
        echo "Activating sub-config \"$SUB_CONFIG\"..."
        if functionExists "$SUB_CONFIG"; then 
            "$SUB_CONFIG"
        else
            echo "$SUB_CONFIG does not exist. Aborting!"
            return 1
        fi
    fi
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
