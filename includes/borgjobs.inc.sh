export BORG=$(which "borgbackup")

checkConfig()
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

isBorgMounted()
{
    [ $(mount | grep "${MOUNTPOINT}" | wc -l) -eq 1 ]
}

getRepoAddress()
{
    if [[ -z $SKIP_REMOTE_REPO_ADDRESS_REWRITE ]] && [[ $SKIP_REMOTE_REPO_ADDRESS_REWRITE -eq 1 ]]; then
         echo "$BORG_REPO"
    else
        isRemote && echo "$REMOTE_SOURCE_SSH:$BORG_REPO" || echo "$BORG_REPO"
    fi
}

info()
{
    executeCallback preMount

    REPO=$(getRepoAddress)

    echo "Listing info of repo $REPO :"
    echo
    "$BORG" info -v --show-rc "$REPO"

    executeCallback postMount
}

listBackups()
{
    executeCallback preMount

    REPO=$(getRepoAddress)

    echo "Enumerating backups in $REPO :"
    "$BORG" list -v "$REPO" 

    executeCallback postMount
}

mountBackup()
{
    executeCallback preMount

    REPO=$(getRepoAddress)

    BACKUP_NAME=$1
    [ "$BACKUP_NAME" == "latest" ] && BACKUP_NAME=$("$BORG" list -v "$REPO" | tail -n1 | head -n1 | cut -d" " -f1)

    MOUNTPOINT="${2:-$BORG_MOUNTPOINT}"

    if isBorgMounted; then
        echo "${MOUNTPOINT} is already mounted. Quitting."
        exit 1
    fi

    echo "Mounting $BACKUP_NAME of $REPO on $MOUNTPOINT..."
    mkdir -p "$MOUNTPOINT"
    "$BORG" mount "$REPO::$BACKUP_NAME" "$MOUNTPOINT"

    executeCallback postMount
}

umountBackup()
{
    executeCallback preUnmount

    MOUNTPOINT="${1:-$BORG_MOUNTPOINT}"

    if isBorgMounted; then
        if ! fusermount -u "${MOUNTPOINT}"; then
            echo "${BORG_S3_MOUNTPOINT} could not be unmounted."
        else
            echo "${MOUNTPOINT} unmounted."
            sleep 5
        fi
    fi

    executeCallback postUnmount
}

runBackup()
{
    executeCallback preBackup

    echo "Executing borgbackup for $BACKUP_NAME_PREFIX backup:"
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
        echo
        echo "Checking backups..."
        echo
        time "$BORG" check -v --show-rc "${BORG_CHECK_PARAMS[@]}" --last ${BACKUPS_TO_CHECK:-2} "$BORG_REPO"
    fi

    echo
    echo "Pruning backups..."
    echo
    time $BORG prune -v --list --show-rc \
        --keep-hourly ${KEEP_HOURLY:-10} \
        --keep-daily ${KEEP_DAILY:-7} \
        --keep-weekly ${KEEP_WEEKLY:-2} \
        --keep-monthly ${KEEP_MONTHLY:-2} \
        "$BORG_REPO"

    echo
    echo "Available backups:"
    echo
    time $BORG list "$BORG_REPO"

    executeCallback postBackup
}

breakLock()
{
    executeCallback preBackup

    echo "Breaking exclusive lock in $BORG_REPO ..."
    "$BORG" break-lock -v --show-rc "$BORG_REPO"

    executeCallback postBackup
}

deleteBackup()
{
    executeCallback preBackup

    echo "Deleting archive $BORG_REPO::$BACKUP_NAME ..."
    "$BORG" delete -v --show-rc "$BORG_REPO::$BACKUP_NAME"

    executeCallback postBackup
}
