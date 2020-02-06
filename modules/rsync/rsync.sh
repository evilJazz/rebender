rsync_name="RSync"
rsync_description="Sync folders locally or across SSH with rsync."

export RSYNC=$(which "rsync")

rsync_usage()
{
    echo "Available actions:"
    echo
    tableOutput "run"
    echo
}

rsync_checkConfig()
{
    if [ -z "$RSYNC" ]; then
        fatal "Please install rsync first."
        return 1
    fi

    if [ -z "$RSYNC_SRC" ]; then
        fatal "RSYNC_SRC not defined."
        return 1
    fi

    if [ -z "$RSYNC_DST" ]; then
        fatal "RSYNC_DST not defined."
        return 1
    fi
}

rsync_action()
{
    ACTION="$1"

    case "$ACTION" in
        dry-run)
            RSYNC_EXTRA_ARGS+=(--dry-run)
            ;& # fall-through !!
        run)
            executeCallback rsync_preRun

            if [ ${RSYNC_BORG_MODE:=0} -eq 1 ]; then
                info "Running rsync in Borg sync mode..."
                # First data chunks...
                "$RSYNC" -Eax --stats --progress "${RSYNC_EXTRA_ARGS[@]}" "$RSYNC_SRC/data"/ "$RSYNC_DST/data"/
                # Finally index and delete old files...
                "$RSYNC" -Eax --stats --progress "${RSYNC_EXTRA_ARGS[@]}" --delete-after "$RSYNC_SRC"/ "$RSYNC_DST"/
            else
                info "Running rsync..."
                "$RSYNC" -Eax --stats --progress "${RSYNC_EXTRA_ARGS[@]}" "$RSYNC_SRC"/ "$RSYNC_DST"/
            fi

            executeCallback rsync_postRun
            ;;
        *)
            usage
            ;;
    esac
}
