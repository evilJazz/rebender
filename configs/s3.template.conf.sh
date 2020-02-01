
isS3Mounted()
{
    [ $(mount | grep "${BORG_S3_MOUNTPOINT}" | wc -l) -eq 1 ]
}

mountS3()
{
    if [ -z "$BORG_S3_MOUNTPOINT" ]; then
        echo "Please define BORG_S3_MOUNTPOINT in the config first. Quitting."
        exit 1
    fi

    if [ -z "$BORG_S3_BUCKET" ]; then
        echo "Please define BORG_S3_BUCKET in the config first. Quitting."
        exit 1
    fi

    if [ -z "$(which s3fs)" ]; then
        echo "Please install s3fs first. Quitting."
        exit 1
    fi

    [ ! -d "${BORG_S3_MOUNTPOINT}" ] && \
        mkdir -p "$BORG_S3_MOUNTPOINT"

    S3FS_PASSWD_FILE="$SCRIPT_ROOT/passwd-s3fs-$CONFIG"

    if [ ! -f "$S3FS_PASSWD_FILE" ]; then
        if [ -z "$AWS_ACCESS_KEY_ID" ]; then
            echo "Please define AWS_ACCESS_KEY_ID env variables first. Quitting."
            exit 1
        fi

        if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
            echo "Please define AWS_SECRET_ACCESS_KEY env variables first. Quitting."
            exit 1
        fi

        echo "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" | tee "$S3FS_PASSWD_FILE" > /dev/null
    fi

    if [ -f "$S3FS_PASSWD_FILE" ]; then
        S3FS_EXTRA_ARGS=",passwd_file=$S3FS_PASSWD_FILE"
        chown root.root "$S3FS_PASSWD_FILE"
        chmod 600 "$S3FS_PASSWD_FILE"
    fi

    # Mount S3 bucket if not mounted...
    if ! isS3Mounted; then
        s3fs -o "endpoint=${AWS_DEFAULT_REGION:-eu-central-1}${S3FS_EXTRA_ARGS}" "${BORG_S3_BUCKET}:/" "${BORG_S3_MOUNTPOINT}" || ( echo "Mounting S3 failed."; exit 1 )
        echo "Waiting for S3 mountpoint ${BORG_S3_MOUNTPOINT} to become active."
        sleep 5
        
        if ! isS3Mounted; then
            echo "Mounting S3 failed."
            exit 1
        fi
    fi
}

umountS3()
{
    if isS3Mounted; then
        if ! umount "${BORG_S3_MOUNTPOINT}"; then
            echo "${BORG_S3_MOUNTPOINT} could not be unmounted."
        else
            echo "${BORG_S3_MOUNTPOINT} unmounted."
            sleep 5
        fi
    fi
}
