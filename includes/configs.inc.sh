
SELFCONTAINED_CONFIG_ROOT="$SCRIPT_ROOT/configs"
export CONFIG_ROOT="${REBENDER_CONFIG_DIR:-$SELFCONTAINED_CONFIG_ROOT}"
unset REBENDER_CONFIG_DIR

configs_list()
{
    find "$CONFIG_ROOT" -maxdepth 1 -mindepth 1 -name "*.conf.sh" -and -not -name "*.template.conf.sh" -type f | sort
}

configs_usage()
{
    echo "Available configs:"
    echo
    for config in $(configs_list); do
        CONFIG_NAME=$(basename "$config")
        CONFIG_NAME=${CONFIG_NAME%.conf.sh}
        tableOutput "$CONFIG_NAME" "$config"
    done
    echo
}

config_load()
{
    SPLIT=$(dirname "$1")
    if [ "$SPLIT" != "." ]; then
        export FULL_CONFIG="$1"
        export CONFIG=$SPLIT
        export SUB_CONFIG=$(basename "$1")
    else
        export FULL_CONFIG="$1"
        export CONFIG="$1"
        export SUB_CONFIG=
    fi

    if [ -z "$CONFIG" ]; then
        fatal "No config specified."
        return 1
    fi

    export CONFIG_FILE="$CONFIG_ROOT/$CONFIG.conf.sh"
    if [ ! -f "$CONFIG_FILE" ]; then
        fatal "$CONFIG_FILE does not exist."
        return 1
    fi

    source "$CONFIG_FILE"

    if [ -n "$SUB_CONFIG" ]; then
        info "Activating sub-config \"$SUB_CONFIG\"..."
        
        if ! functionExists "$SUB_CONFIG"; then 
            fatal "$SUB_CONFIG does not exist."
            return 1
        fi

        executeCallback "$SUB_CONFIG"
    fi
}
