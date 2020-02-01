#!/bin/bash
SCRIPT_FILENAME=$(readlink -f "`cd \`dirname \"$0\"\`; pwd`/`basename \"$0\"`")
SCRIPT_ROOT=$(dirname "$SCRIPT_FILENAME")
cd "$SCRIPT_ROOT"

set -e -o pipefail
source "includes/common.inc.sh"
source "includes/borgjobs.inc.sh"

usage()
{
    echo "Usage: $0 (list|info|mount|umount|create|check) (config) ..."
    echo
    echo "      list (config)"
    echo "      info (config)"
    echo "      mount (config) [backup name] [mountpoint]"
    echo "      umount (config)"
    echo "      create (config)"
    echo "      delete (config) [backup name]"
    echo "      check (config)"
    echo "      break-lock (config)"
    echo
}

[ $# -lt 1 ] && usage && exit 1

ACTION="$1"
loadConfig "$2"
checkConfig

if isRemote && ! [[ "$ACTION" =~ mount$ ]]; then
    runOnRemote "$@"
    EXIT_CODE=$?
    exit $EXIT_CODE
fi

shift 2

case "$ACTION" in
    list)
        listBackups
        ;;
    info)
        info
        ;;
    mount)
        BACKUP_NAME="$1"
        MOUNTPOINT="$2"

        if [ -z "$BACKUP_NAME" ]; then
            if isRemote && [[ "$RUNNING_REMOTELY" -eq 0 ]]; then
                runOnRemote list "$CONFIG"
            else
                listBackups
            fi
            
            echo
            echo "Now re-run with "$0" mount "$CONFIG" [backup name] [mountpoint default: $BORG_MOUNTPOINT ]"
            exit 0
        fi

        mountBackup "$BACKUP_NAME" "$MOUNTPOINT"
        ;;
    umount)
        MOUNTPOINT="$1"

        if [[ -n "$MOUNTPOINT" ]] && [[ ! -d "$MOUNTPOINT" ]]; then
            echo "The mountpoint $MOUNTPOINT does not exist."
            exit 1
        fi

        umountBackup "$MOUNTPOINT"
        ;;
    create)
        runBackup
        ;;
    delete)
        BACKUP_NAME="$1"

        if [ -z "$BACKUP_NAME" ]; then
            listBackups
            echo
            echo "Now re-run with "$0" delete "$CONFIG" [timestamp]"
            exit 0
        fi

        deleteBackup "$BACKUP_NAME"
        ;;
    check)
        runBackup check
        ;;
    break-lock)
        breakLock
        ;;
    *)
        if functionExists "$ACTION"; then
            echo "Executing custom action: $ACTION"
            "$ACTION" "$@"
        else
            echo "Unknown action $ACTION. Qutting."
            usage
        fi
        ;;
esac

exit 0
