#!/bin/bash

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
