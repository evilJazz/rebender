s3sync_name="AWS"
s3sync_description="Sync folders with aws sync."

export AWSCLI=$(which "aws")

s3sync_usage()
{
    echo "Available actions:"
    echo
    tableOutput "run"
    echo
}

s3sync_checkConfig()
{
    if [ -z "$AWSCLI" ]; then
        fatal "Please install aws first."
        return 1
    fi

    if [ -z "$S3SYNC_SRC" ]; then
        fatal "S3SYNC_SRC not defined."
        return 1
    fi

    if [ -z "$S3SYNC_DST" ]; then
        fatal "S3SYNC_DST not defined."
        return 1
    fi
}

s3sync_action()
{
    ACTION="$1"

    case "$ACTION" in
        dry-run)
            S3SYNC_EXTRA_ARGS+=(--dryrun)
            ;& # fall-through !!
        run)
            executeCallback s3sync_preRun

            if [ ${S3SYNC_BORG_MODE:=0} -eq 1 ]; then
                info "Running aws s3 sync in Borg sync mode..."
                # First data chunks...
                "$AWSCLI" s3 sync "${S3SYNC_EXTRA_ARGS[@]}" "$S3SYNC_SRC/data"/ "$S3SYNC_DST/data"/
                # Finally index and delete old files...
                "$AWSCLI" s3 sync "${S3SYNC_EXTRA_ARGS[@]}" --delete "$S3SYNC_SRC"/ "$S3SYNC_DST"/
            else
                info "Running aws s3 sync..."
                "$AWSCLI" s3 sync "${S3SYNC_EXTRA_ARGS[@]}" "$S3SYNC_SRC"/ "$S3SYNC_DST"/
            fi

            executeCallback s3sync_postRun
            ;;
        *)
            usage
            ;;
    esac
}
