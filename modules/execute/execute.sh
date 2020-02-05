execute_name="Execute"
execute_description="Execute actions or run commands."

execute_usage()
{
    echo "Available actions:"
    echo
    tableOutput "default"
    echo
}

execute_checkConfig()
{
    if [ "$2" == "default" ]; then
        # Default action requested?
        if [ -z "$DEFAULT_ACTION" ]; then
            echo "DEFAULT_ACTION not defined. Aborting!"
            return 1
        fi

        if [ -z "$DEFAULT_MODULE" ]; then
            echo "DEFAULT_MODULE not defined. Aborting!"
            return 1
        fi
    fi
}

execute_action()
{
    ACTION="$1"

    case "$ACTION" in
        default)
            moduleCheckConfig "$DEFAULT_MODULE" "$@"
            moduleAction "$DEFAULT_MODULE" "$DEFAULT_ACTION" "$@"
            ;;
        *)
            executeCallback "$ACTION" || usage
            ;;
    esac
}
