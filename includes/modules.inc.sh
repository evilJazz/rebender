MODULE_ROOT="$SCRIPT_ROOT/modules"

modules_list()
{
    find "$MODULE_ROOT" -maxdepth 1 -mindepth 1 -type d | sort
}

modules_usage()
{
    echo "Available modules:"
    echo
    for module in $(modules_list); do
        MODULE=$(basename "$module")

        MODULE_NAME_KEY="${MODULE}_name"
        MODULE_NAME=${!MODULE_NAME_KEY}

        MODULE_DESCRIPTION_KEY="${MODULE}_description"
        MODULE_DESCRIPTION=${!MODULE_DESCRIPTION_KEY}

        tableOutput "$MODULE" "$MODULE_NAME" "$MODULE_DESCRIPTION"
    done
    echo
}

modules_load()
{
    for module in $(modules_list); do
        MODULE_NAME=$(basename "$module")
        source "$module/${MODULE_NAME}.sh"
    done
}

module_isValid()
{
    [[ -d "$MODULE_ROOT/$1" ]] && [[ -f "$MODULE_ROOT/$1/$1.sh" ]]
}

module_executeFunction()
{
    MODULE="$1"
    FN_NAME="$1_$2"
    shift 2
    functionExists "$FN_NAME" && eval "$FN_NAME" "$@"
}

module_usage()
{
    eval "$1_usage"
}

module_checkConfig()
{
    MODULE="$1"; shift 1
    module_executeFunction "$MODULE" "checkConfig" "$@"
}

module_action()
{
    MODULE="$1"; shift 1
    module_executeFunction "$MODULE" "action" "$@"
}

module_action_isLocal()
{
    MODULE="$1"; shift 1
    module_executeFunction "$MODULE" "action_isLocal" "$@" || false
}
