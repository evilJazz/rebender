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
            fatal "DEFAULT_ACTION not defined."
            return 1
        fi

        if [ -z "$DEFAULT_MODULE" ]; then
            fatal "DEFAULT_MODULE not defined."
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
            executeCallback "$ACTION" || usage
            ;;
    esac
}
