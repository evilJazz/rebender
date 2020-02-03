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
        echo "Please install rsync first. Quitting."
        return 1
    fi

    if [ -z "$RSYNC_SRC" ]; then
        echo "RSYNC_SRC not defined. Aborting!"
        return 1
    fi

    if [ -z "$RSYNC_DST" ]; then
        echo "RSYNC_DST not defined. Aborting!"
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
                echo "Running rsync in Borg sync mode..."
                # First data chunks...
                "$RSYNC" -Eax --stats --progress "${RSYNC_EXTRA_ARGS[@]}" "$RSYNC_SRC/data"/ "$RSYNC_DST/data"/
                # Finally index and delete old files...
                "$RSYNC" -Eax --stats --progress "${RSYNC_EXTRA_ARGS[@]}" --delete-after "$RSYNC_SRC"/ "$RSYNC_DST"/
            else
                echo "Running rsync..."
                "$RSYNC" -Eax --stats --progress "${RSYNC_EXTRA_ARGS[@]}" "$RSYNC_SRC"/ "$RSYNC_DST"/
            fi

            executeCallback rsync_postRun
            ;;
        *)
            usage
            ;;
    esac
}
