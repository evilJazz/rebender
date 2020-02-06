
borg_isMounted()
{
    [ $(mount | grep "${MOUNTPOINT}" | wc -l) -eq 1 ]
}

borg_getRepoAddress()
{
    if [[ -z $SKIP_REMOTE_REPO_ADDRESS_REWRITE ]] && [[ $SKIP_REMOTE_REPO_ADDRESS_REWRITE -eq 1 ]]; then
        echo "$BORG_REPO"
    else
        remote_isRequested && echo "$REMOTE_SSH:$BORG_REPO" || echo "$BORG_REPO"
    fi
}

borg_info()
{
    executeCallback borg_preMount

    REPO=$(borg_getRepoAddress)

    info "Listing info of repo $REPO :"
    "$BORG" info -v --show-rc "$REPO"

    executeCallback borg_postMount
}

borg_listBackups()
{
    executeCallback borg_preMount

    REPO=$(borg_getRepoAddress)

    info "Enumerating backups in $REPO :"
    "$BORG" list -v "$REPO" 

    executeCallback borg_postMount
}

borg_mountBackup()
{
    executeCallback borg_preMount

    REPO=$(borg_getRepoAddress)

    BACKUP_NAME=$1
    [ "$BACKUP_NAME" == "latest" ] && BACKUP_NAME=$("$BORG" list -v "$REPO" | tail -n1 | head -n1 | cut -d" " -f1)

    MOUNTPOINT="${2:-$BORG_MOUNTPOINT}"

    if borg_isMounted; then
        fatal "${MOUNTPOINT} is already mounted."
        exit 1
    fi

    info "Mounting $BACKUP_NAME of $REPO on $MOUNTPOINT..."
    mkdir -p "$MOUNTPOINT"
    "$BORG" mount "$REPO::$BACKUP_NAME" "$MOUNTPOINT"

    executeCallback borg_postMount
}

borg_umountBackup()
{
    executeCallback borg_preUnmount

    MOUNTPOINT="${1:-$BORG_MOUNTPOINT}"

    if borg_isMounted; then
        if ! fusermount -u "${MOUNTPOINT}"; then
            error "${BORG_S3_MOUNTPOINT} could not be unmounted."
        else
            info "${MOUNTPOINT} unmounted."
            sleep 5
        fi
    fi

    executeCallback borg_postUnmount
}

borg_runBackup()
{
    executeCallback borg_preBackup

    info "Executing borgbackup for $BACKUP_NAME_PREFIX backup:"
    echo

    if [ ! -d "$BORG_REPO" ]; then
        mkdir -p "$BORG_REPO"
        "$BORG" init -e repokey "$BORG_REPO"
    fi

    [ -t 0 ] && ADDPARAMS="--progress"

    time "$BORG" create \
        --show-rc \
        --numeric-owner \
        -C "${BORG_COMPRESSION:-lz4}" -v --stats $ADDPARAMS \
        "${BORG_PARAMS[@]}" \
        "$BORG_REPO::$BACKUP_NAME_PREFIX-$(date +%Y-%m-%d_%H%M)" "${SOURCE[@]}"

    if [ "$1" == "check" ]; then
        borg_runCheck
    fi

    echo
    info "Pruning backups..."
    echo
    time $BORG prune -v --list --show-rc \
        --keep-hourly ${KEEP_HOURLY:-10} \
        --keep-daily ${KEEP_DAILY:-7} \
        --keep-weekly ${KEEP_WEEKLY:-2} \
        --keep-monthly ${KEEP_MONTHLY:-2} \
        "$BORG_REPO"

    echo
    info "Available backups:"
    echo
    time $BORG list "$BORG_REPO"

    executeCallback borg_postBackup
}

borg_runCheck()
{
    executeCallback borg_preCheck

    info "Checking backups..."
    time "$BORG" check -v --show-rc "${BORG_CHECK_PARAMS[@]}" --last ${BACKUPS_TO_CHECK:-2} "$BORG_REPO"

    executeCallback borg_postCheck
}

borg_breakLock()
{
    executeCallback borg_preBackup

    info "Breaking exclusive lock in $BORG_REPO ..."
    "$BORG" break-lock -v --show-rc "$BORG_REPO"

    executeCallback borg_postBackup
}

borg_deleteBackup()
{
    executeCallback borg_preBackup

    info "Deleting archive $BORG_REPO::$BACKUP_NAME ..."
    "$BORG" delete -v --show-rc "$BORG_REPO::$BACKUP_NAME"

    executeCallback borg_postBackup
}
