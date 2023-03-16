
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
    if [[ -z $BORG_SKIP_REMOTE_REPO_ADDRESS_REWRITE ]] && [[ $BORG_SKIP_REMOTE_REPO_ADDRESS_REWRITE -eq 1 ]]; then
        echo "$BORG_REPO"
    else
        if ! borg_isRemoteRepo && remote_isRequested; then
            echo "$REMOTE_SSH:$BORG_REPO"
        else
            echo "$BORG_REPO"
        fi
    fi
}

borg_execute()
{
    export BORG_BASE_DIR="$HOME/.rebender/borg/$PROFILE"
    mkdir -p "$BORG_BASE_DIR"
    "$BORG" "$@"
    unset BORG_BASE_DIR
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
        if remote_ssh "${BORG_SSH_SERVER}" "[ ! -d \"$BORG_REPO_LOCAL\" ]"; then
            info "Repository $BORG_REPO does not exist. Attempting to initialize it."
    
            # TODO: Use borg init --make-parent-dirs instead, requires newer version.
            remote_ssh "${BORG_SSH_SERVER}" "mkdir -p \"$BORG_REPO_LOCAL\""
            borg_execute init -e repokey "$BORG_REPO"
        fi
    else
        if [ ! -d "$BORG_REPO" ]; then
            info "Repository $BORG_REPO does not exist. Attempting to initialize it."
            
            mkdir -p "$BORG_REPO"
            borg_execute init -e repokey "$BORG_REPO"
        fi
    fi

    [ -t 0 ] && ADDPARAMS="--progress"

    RC=0
    borg_execute create \
        --show-rc \
        --numeric-owner \
        -C "${BORG_COMPRESSION:-lz4}" -v --stats $ADDPARAMS \
        "${BORG_PARAMS[@]}" \
        "$BORG_REPO::$BORG_BACKUP_NAME_PREFIX-$(date +%Y-%m-%d_%H%M)" "${BORG_SOURCE[@]}" || RC=$?

    # Catch error code but ignore 1 since it might only be warnings...
    [ $RC -gt 1 ] && exit $RC

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

borg_runExtract()
{
    executeCallback borg_preExtract

    BACKUP_NAME=$1
    [ "$BACKUP_NAME" == "latest" ] && BACKUP_NAME=$(borg_execute list -v "$BORG_REPO" | tail -n1 | head -n1 | cut -d" " -f1)

    RESTORE_POINT=$2

    shift 2

    info "Extracting backups @ to $RESTORE_POINT..."
    mkdir -p "$RESTORE_POINT"
    cd "$RESTORE_POINT"
    borg_execute extract -v --show-rc "${BORG_EXTRACT_PARAMS[@]}" "$BORG_REPO::$BACKUP_NAME" "$@"

    executeCallback borg_postExtract
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

    info "Deleting archive $BORG_REPO::$1 ..."
    borg_execute delete -vv --show-rc "$BORG_REPO::$1"

    executeCallback borg_postBackup
}
