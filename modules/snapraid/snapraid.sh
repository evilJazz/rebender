snapraid_name="Snapraid"
snapraid_description="Secure hard drives against hardware failures."

export SNAPRAID=$(which "snapraid")

snapraid_usage()
{
    echo "Available actions:"
    echo
    tableOutput "run"
    echo
}

snapraid_checkConfig()
{
    if [ -z "$SNAPRAID" ]; then
        echo "Please install snapraid first. Quitting."
        return 1
    fi
}

snapraid_action()
{
    ACTION="$1"

    echo "ACTION: $ACTION"

    case "$ACTION" in
        run)
            executeCallback snapraid_preRun

            echo
            echo "---------------------------------------------------------"

            echo "Running snapraid diff..."
            "$SNAPRAID" diff || true

            echo
            echo "---------------------------------------------------------"
            
            for RUN in FIRST SECOND
            do
                echo "Running snapraid sync $RUN RUN..."
                if [ -t 0 ]; then
                        "$SNAPRAID" --force-zero --force-empty --pre-hash sync
                    else
                        "$SNAPRAID" --force-zero --force-empty --pre-hash sync | grep -v 'MB/s'
                fi
            done
            
            echo
            echo "---------------------------------------------------------"

            
            echo
            echo "---------------------------------------------------------"

            echo "Running snapraid status..."
            "$SNAPRAID" status

            echo
            echo "---------------------------------------------------------"

            echo "Running snapraid scrub -v..."
            if [ -t 0 ]; then
                "$SNAPRAID" scrub -p${SNAPRAID_SCRUB_PERCENT:-2}
            else
                "$SNAPRAID" scrub -p${SNAPRAID_SCRUB_PERCENT:-2} | grep -v 'MB/s'
            fi

            #echo
            #echo "---------------------------------------------------------"

            # DO NOT ACTIVATE AGAIN AS IT WILL MOST DEFINITELY DESTROY RUNNING VMS
            # BY WRITING INTO THE MODIFIED VM DISK IMAGES....
            #echo "Running snapraid -e fix..."
            #"$SNAPRAID" -e fix

            echo
            echo "---------------------------------------------------------"

            echo "Running snapraid status..."
            "$SNAPRAID" status

            executeCallback snapraid_postRun
            ;;
        *)
            usage
            ;;
    esac
}
