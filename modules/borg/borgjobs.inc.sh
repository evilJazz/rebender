
borg_isMounted()
{
    [ $(mount | grep "${MOUNTPOINT}" | wc -l) -eq 1 ]
}

borg_isRemoteRepo()
{
    [[ "$BORG_REPO" =~ (.*@)?.*: ]]
}

borg_getRepoAddress()
{
    if [[ -z $SKIP_REMOTE_REPO_ADDRESS_REWRITE ]] && [[ $SKIP_REMOTE_REPO_ADDRESS_REWRITE -eq 1 ]]; then
        echo "$BORG_REPO"
    else
        remote_isRequested && echo "$REMOTE_SSH:$BORG_REPO" || echo "$BORG_REPO"
    fi
}

borg_execute()
{
    eval time "$BORG" "$@"
}

borg_info()
{
    executeCallback borg_preMount

    REPO=$(borg_getRepoAddress)

    info "Listing info of repo $REPO :"
    borg_execute info -v --show-rc "$REPO"

    executeCallback borg_postMount
}

borg_listBackups()
{
    executeCallback borg_preMount

    REPO=$(borg_getRepoAddress)

    info "Enumerating backups in $REPO :"
    borg_execute list -v "$REPO" 

    executeCallback borg_postMount
}

borg_mountBackup()
{
    executeCallback borg_preMount

    REPO=$(borg_getRepoAddress)

    BACKUP_NAME=$1
    [ "$BACKUP_NAME" == "latest" ] && BACKUP_NAME=$(borg_execute list -v "$REPO" | tail -n1 | head -n1 | cut -d" " -f1)

    MOUNTPOINT="${2:-$BORG_MOUNTPOINT}"

    if borg_isMounted; then
        fatal "${MOUNTPOINT} is already mounted."
        exit 1
    fi

    info "Mounting $BACKUP_NAME of $REPO on $MOUNTPOINT..."
    mkdir -p "$MOUNTPOINT"
    borg_execute mount -o allow_other "$REPO::$BACKUP_NAME" "$MOUNTPOINT"

    executeCallback borg_postMount
}

borg_umountBackup()
{
    executeCallback borg_preUnmount

    MOUNTPOINT="${1:-$BORG_MOUNTPOINT}"

    if borg_isMounted; then
        if ! fusermount -u "${MOUNTPOINT}"; then
            error "${MOUNTPOINT} could not be unmounted."
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

    info "Executing borgbackup for $BORG_BACKUP_NAME_PREFIX backup:"
    echo

    if borg_isRemoteRepo; then
        BORG_SSH_SERVER=${BORG_REPO%:*}
        BORG_REPO_LOCAL=${BORG_REPO#*:}
        remote_ssh "${BORG_SSH_SERVER}" \
            "[ ! -d \"$BORG_REPO_LOCAL\" ] && \
            (mkdir -p \"$BORG_REPO_LOCAL\";\
            \"$BORG\" init -e repokey \"$BORG_REPO_LOCAL\") || true"
    else
        if [ ! -d "$BORG_REPO" ]; then
            mkdir -p "$BORG_REPO"
            borg_execute init -e repokey "$BORG_REPO"
        fi
    fi

    [ -t 0 ] && ADDPARAMS="--progress"

    borg_execute create \
        --show-rc \
        --numeric-owner \
        -C "${BORG_COMPRESSION:-lz4}" -v --stats $ADDPARAMS \
        "${BORG_PARAMS[@]}" \
        "$BORG_REPO::$BORG_BACKUP_NAME_PREFIX-$(date +%Y-%m-%d_%H%M)" "${BORG_SOURCE[@]}"

    if [ "$1" == "check" ]; then
        borg_runCheck
    fi

    echo
    info "Pruning backups..."
    echo
    borg_execute prune -v --list --show-rc \
        --keep-hourly ${BORG_KEEP_HOURLY:-10} \
        --keep-daily ${BORG_KEEP_DAILY:-7} \
        --keep-weekly ${BORG_KEEP_WEEKLY:-2} \
        --keep-monthly ${BORG_KEEP_MONTHLY:-2} \
        "$BORG_REPO"

    echo
    info "Available backups:"
    echo
    borg_execute list "$BORG_REPO"

    executeCallback borg_postBackup
}

borg_runCheck()
{
    executeCallback borg_preCheck

    info "Checking backups..."
    borg_execute check -v --show-rc "${BORG_CHECK_PARAMS[@]}" --last ${BORG_BACKUPS_TO_CHECK:-2} "$BORG_REPO"

    executeCallback borg_postCheck
}

borg_breakLock()
{
    executeCallback borg_preBackup

    info "Breaking exclusive lock in $BORG_REPO ..."
    borg_execute break-lock -v --show-rc "$BORG_REPO"

    executeCallback borg_postBackup
}

borg_deleteBackup()
{
    executeCallback borg_preBackup

    info "Deleting archive $BORG_REPO::$BACKUP_NAME ..."
    borg_execute delete -v --show-rc "$BORG_REPO::$BACKUP_NAME"

    executeCallback borg_postBackup
}
