execute_name="Execute"
execute_description="Execute actions or run commands."

execute_usage()
{
    echo "Available actions:"
    echo
    tableOutput "default"

    for action in ${AVAILABLE_EXECUTE_ACTIONS[@]}; do
        tableOutput "$action"
    done
    echo
}

execute_checkConfig()
{
    if [ "$2" == "default" ]; then
        # Default action requested?
        if [ -z "$DEFAULT_ACTION" ]; then
            fatal "DEFAULT_ACTION not defined."
            return 1
        fi

        if [ -z "$DEFAULT_MODULE" ]; then
            fatal "DEFAULT_MODULE not defined."
            return 1
        fi
    else
        if ! (functionExists "$ACTION" || functionExists "${ACTION}_onRemote"); then
            fatal "Action by name "$ACTION" is not defined."
            return 1
        fi
    fi
}

execute_action()
{
    ACTION="$1"

    case "$ACTION" in
        default)
            module_checkConfig "$DEFAULT_MODULE" "$@"
            module_action "$DEFAULT_MODULE" "$DEFAULT_ACTION" "$@"
            ;;
        *)
            executeCallback "$ACTION"
            ;;
    esac
}
