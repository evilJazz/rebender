#!/bin/bash

COL_NORMAL="\e[0m"
COL_RED="\e[01;31m"
COL_YELLOW="\e[01;33m"
COL_GREEN="\e[01;32m"

info()
{
    printf "$COL_GREEN%s$COL_NORMAL\n" "$@"
}

fatal()
{
    error "$@ Quitting."
    return 1
}

error()
{
    echo -e "$COL_RED$@$COL_NORMAL"
}

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
        REMOTE_CALLBACK_NAME="${1}_onRemote"
        shift 1
        if functionExists "$REMOTE_CALLBACK_NAME"; then
            "$REMOTE_CALLBACK_NAME" "$@"
        fi
    fi
}

findExistingDirectory()
{
    # Bash cannot pass arrays as args, so look up by name...
    ARRAY_NAME=$1[@]
    PATHS=("${!ARRAY_NAME}")

    for path in "${PATHS[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

quote()
{
    [ $# -gt 0 ] && printf "%q " "$@" | sed 's/ $//'
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
