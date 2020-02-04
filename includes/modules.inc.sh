MODULE_ROOT="$SCRIPT_ROOT/modules"

modulesList()
{
    find "$MODULE_ROOT" -maxdepth 1 -mindepth 1 -type d | sort
}

modulesUsage()
{
    echo "Available sub-modules:"
    echo
    for module in $(modulesList); do
        MODULE=$(basename "$module")

        MODULE_NAME_KEY="${MODULE}_name"
        MODULE_NAME=${!MODULE_NAME_KEY}

        MODULE_DESCRIPTION_KEY="${MODULE}_description"
        MODULE_DESCRIPTION=${!MODULE_DESCRIPTION_KEY}

        tableOutput "$MODULE" "$MODULE_NAME" "$MODULE_DESCRIPTION"
    done
    echo
}

modulesLoad()
{
    for module in $(modulesList); do
        MODULE_NAME=$(basename "$module")
        source "$module/${MODULE_NAME}.sh"
    done
}

isValidModule()
{
    [[ -d "$MODULE_ROOT/$1" ]] && [[ -f "$MODULE_ROOT/$1/$1.sh" ]]
}

moduleExecuteFunction()
{
    MODULE="$1"
    FN_NAME="$1_$2"
    shift 2
    functionExists "$FN_NAME" && eval "$FN_NAME" "$@"
}

moduleUsage()
{
    eval "$1_usage"
}

moduleCheckConfig()
{
    MODULE="$1"; shift 1
    moduleExecuteFunction "$MODULE" "checkConfig" "$@"
}

moduleAction()
{
    MODULE="$1"; shift 1
    moduleExecuteFunction "$MODULE" "action" "$@"
}

module_isLocalAction()
{
    MODULE="$1"; shift 1
    moduleExecuteFunction "$MODULE" "isLocalAction" "$@" || false
}
