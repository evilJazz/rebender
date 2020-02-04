
SELFCONTAINED_CONFIG_ROOT="$SCRIPT_ROOT/configs"
export CONFIG_ROOT="${REBENDER_CONFIG_DIR:-$SELFCONTAINED_CONFIG_ROOT}"
unset REBENDER_CONFIG_DIR

configList()
{
    find "$CONFIG_ROOT" -maxdepth 1 -mindepth 1 -name "*.conf.sh" -and -not -name "*.template.conf.sh" -type f | sort
}

configUsage()
{
    echo "Available configs:"
    echo
    for config in $(configList); do
        CONFIG_NAME=$(basename "$config")
        CONFIG_NAME=${CONFIG_NAME%.conf.sh}
        tableOutput "$CONFIG_NAME" "$config"
    done
    echo
}

loadConfig()
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
        echo "No config specified. Aborting!"
        return 1
    fi

    export CONFIG_FILE="$CONFIG_ROOT/$CONFIG.conf.sh"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$CONFIG_FILE does not exist. Aborting!"
        return 1
    fi

    source "$CONFIG_FILE"

    if [ -n "$SUB_CONFIG" ]; then
        echo "Activating sub-config \"$SUB_CONFIG\"..."
        if functionExists "$SUB_CONFIG"; then 
            "$SUB_CONFIG"
        else
            echo "$SUB_CONFIG does not exist. Aborting!"
            return 1
        fi
    fi
}
