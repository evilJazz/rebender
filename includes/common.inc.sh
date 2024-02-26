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

failOnError()
{
    [ "$1" == "on" ] && set -eE -o pipefail || set +eE
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

executeCallbackRaw()
{
    local CALLBACK_NAME=$1
    shift 1

    if functionExists "$CALLBACK_NAME"; then
        info ">> Executing $CALLBACK_NAME"
        "$CALLBACK_NAME" "$@"
        info "<< $REMOTE_CALLBACK_NAME done."
    fi
}

executeCallback()
{
    local CALLBACK_NAME=$1
    shift 1
    
    if [ "$RUNNING_REMOTELY" -eq 0 ]; then
        executeCallbackRaw "${CALLBACK_NAME}_onLocal" "$@"
    fi

    executeCallbackRaw "${CALLBACK_NAME}"

    if [ "$RUNNING_REMOTELY" -eq 1 ]; then
        executeCallbackRaw "${CALLBACK_NAME}_onRemote" "$@"
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

function common_cleanUp() {
    children="$(jobs -p | xargs)"

    info "Cleaning up processes $children..."
    if [ -n "$children" ]; then
        kill $children
    fi
}
