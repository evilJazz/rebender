source "modules/borg/borgjobs.inc.sh"

borg_name="Borg Backup"
borg_description="Manage backups with Borg Backup."

export BORG=$(which "borgbackup")

borg_usage()
{
    echo "Available actions:"
    echo
    tableOutput "list"
    tableOutput "info"
    tableOutput "mount" "[backup name] [mountpoint]"
    tableOutput "umount"
    tableOutput "create"
    tableOutput "delete" "[backup name]"
    tableOutput "check"
    tableOutput "break-lock"
    echo
}

borg_checkConfig()
{
    if [ -z "$BORG" ]; then
        echo "Please install borgbackup first. Quitting."
        exit 1
    fi

    if [ -z "$BORG_PASSPHRASE" ]; then
        echo "BORG_PASSPHRASE environment variable is not set. Aborting!"
        exit 1
    fi

    if [ -z "$BORG_REPO" ]; then
        echo "BORG_REPO environment variable is not set. Aborting!"
        exit 1
    fi
}

borg_isLocalAction()
{
    [[ "$1" =~ mount$ ]]
}

borg_action()
{
    ACTION="$1"
    shift 1

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
                    runOnRemote "$CONFIG" borg list
                else
                    listBackups
                fi
                
                echo
                echo "Now re-run with "$0" "$CONFIG" borg mount [backup name] [mountpoint default: $BORG_MOUNTPOINT ]"
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
                echo "Now re-run with "$0" "$CONFIG" borg delete [timestamp]"
                exit 0
            fi

            deleteBackup "$BACKUP_NAME"
            ;;
        check)
            runCheck
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
}
