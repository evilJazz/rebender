source "modules/borg/borgjobs.inc.sh"

borg_name="Borg Backup"
borg_description="Manage backups with Borg Backup."

export BORG=$(which "borg")

BORG_DEFAULT_RSH=("${REMOTE_DEFAULT_RSH[@]}")
export BORG_RSH="${BORG_DEFAULT_RSH[@]}"

export BORG_ALWAYS_PRUNE=true
export BORG_ALWAYS_COMPACT=true

borg_usage()
{
    echo "Available actions:"
    echo
    tableOutput "list"
    tableOutput "info"
    tableOutput "mount" "[backup name | latest] [mountpoint]"
    tableOutput "umount"
    tableOutput "mount-local" "[backup name | latest] [mountpoint]"
    tableOutput "umount-local"
    tableOutput "create"
    tableOutput "restore" "[backup name | latest] [restore directory] [path ...]"
    tableOutput "delete" "[backup name]"
    tableOutput "delete-checkpoints"
    tableOutput "prune"
    tableOutput "compact"
    tableOutput "check"
    tableOutput "break-lock"
    echo
}

borg_checkConfig()
{
    if [ -z "$BORG" ]; then
        fatal "Please install borgbackup first."
        return 1
    fi

    if [ -z "$BORG_PASSPHRASE" ]; then
        fatal "BORG_PASSPHRASE environment variable is not set."
        return 1
    fi

    if [ -z "$BORG_REPO" ]; then
        fatal "BORG_REPO environment variable is not set."
        return 1
    fi
}

borg_action_isLocal()
{
    [[ "$1" =~ mount-local$ ]]
}

borg_action()
{
    ACTION="$1"
    shift 1

    case "$ACTION" in
        list)
            borg_listBackups
            ;;
        info)
            borg_info
            ;;
        mount|mount-local)
            BACKUP_NAME="$1"
            MOUNTPOINT="$2"

            if remote_isRequested && [[ "$ACTION" == "mount-local" && "$BORG_USE_REMOTE_SSH_AS_PROXY" -eq 1 ]]; then
                info "Setting up SSH for proxying Borg repo $BORG_REPO via $REMOTE_SSH"
                export BORG_RSH="${BORG_DEFAULT_RSH[@]} -J \"$REMOTE_SSH\""
            fi

            if [ -z "$BACKUP_NAME" ]; then
                if remote_isRequested; then
                    remote_run "$FULL_CONFIG" borg list
                else
                    borg_listBackups
                fi
                
                echo
                echo "Now re-run with "$0" "$FULL_CONFIG" borg $ACTION [backup name] [mountpoint default: $BORG_MOUNTPOINT ]"
                exit 0
            fi

            borg_mountBackup "$BACKUP_NAME" "$MOUNTPOINT"
            ;;
        umount|umount-local|unmount|unmount-local)
            MOUNTPOINT="$1"

            if [[ -n "$MOUNTPOINT" ]] && [[ ! -d "$MOUNTPOINT" ]]; then
                error "The mountpoint $MOUNTPOINT does not exist."
                exit 1
            fi

            borg_umountBackup "$MOUNTPOINT"
            ;;
        create)
            borg_runBackup
            ;;
        restore)
            BACKUP_NAME="$1"
            RESTORE_POINT="$2"

            if [ -z "$BACKUP_NAME" ]; then
                if remote_isRequested; then
                    remote_run "$FULL_CONFIG" borg list
                else
                    borg_listBackups
                fi
                
                echo
                echo "Now re-run with "$0" "$FULL_CONFIG" borg $ACTION [backup name] [restore directory] [path ...]"
                exit 0
            fi

            if [ -z "$RESTORE_POINT" ]; then
                error "Please specify a restore directory."
                exit 1
            fi

            borg_runExtract "$@"
            ;;
        delete)
            BACKUP_NAME="$1"

            if [ -z "$BACKUP_NAME" ]; then
                borg_listBackups
                echo
                echo "Now re-run with "$0" "$FULL_CONFIG" borg delete [timestamp]"
                exit 0
            fi

            borg_deleteBackup "$BACKUP_NAME"
            ;;
        delete-checkpoints)
            CHECKPOINTS=$(borg_listBackups | grep ".checkpoint" | cut -d" " -f1 | xargs)

            for CHECKPOINT in $CHECKPOINTS; do
                echo "Deleting $CHECKPOINT..."
                borg_deleteBackup "$CHECKPOINT"
            done
            ;;
        prune)
            borg_pruneBackups
            ;;
        compact)
            borg_compactBackups
            ;;
        check)
            borg_runCheck
            ;;
        break-lock)
            borg_breakLock
            ;;
        *)
            if functionExists "$ACTION"; then
                info "Executing custom action: $ACTION"
                "$ACTION" "$@"
            else
                error "Unknown action $ACTION. Qutting."
                usage
            fi
            ;;
    esac
}
