#!/bin/bash
SCRIPT_FILENAME=$(readlink -f "`cd \`dirname \"$0\"\`; pwd`/`basename \"$0\"`")
SCRIPT_ROOT=$(dirname "$SCRIPT_FILENAME")
cd "$SCRIPT_ROOT"

set -m

source "includes/common.inc.sh"
failOnError on
source "includes/configs.inc.sh"
source "includes/modules.inc.sh"
source "includes/remote.inc.sh"

cleanUp()
{
    info "Stopping execution..."
    executeCallback remote_cleanUp
    executeCallback common_cleanUp
}
trap cleanUp SIGINT SIGHUP SIGTERM EXIT

usage()
{
    if module_isValid "$MODULE"; then
        echo "Usage: $0 $FULL_CONFIG $MODULE (action) ..."
        echo
        if [ -z "$CONFIG" ]; then
            configs_usage
        fi
        module_usage "$MODULE"
    else
        echo "Usage: $0 ${FULL_CONFIG:-(config[/sub-config])} (module) (action) ..."
        echo
        if [ -z "$CONFIG" ]; then
            configs_usage
        fi
        modules_usage
    fi
}

# Startup...
modules_load
if ! config_load "$1"; then
    FULL_CONFIG=
    CONFIG=
    echo
    usage
    exit 1
fi

MODULE="$2"
if ! module_isValid "$MODULE"; then
    error "Module by name $MODULE does not exist."
    echo
    usage
    exit 1
fi

[ $# -lt 3 ] && (usage; exit 1)

remote_init

executeCallback initialization

ACTION="$3"
#if [ ! "$RUNNING_REMOTELY" -eq 1 ]; then
    info "Executing"
    info "    config: $CONFIG"
    info "    sub-config: $SUB_CONFIG"
    info "    module: $MODULE"
    info "    action: $ACTION"
#fi

if remote_isRequested && ! module_action_isLocal "$MODULE" "$ACTION"; then
    remote_pushAppConfig

    info "Running config remotely..."
    remote_run "$@"
    EXIT_CODE=$?
    exit $EXIT_CODE
fi

[ ! "$RUNNING_REMOTELY" -eq 1 ] && info "Running config locally..."
shift 3

module_checkConfig "$MODULE" "$ACTION" "$@"
module_action "$MODULE" "$ACTION" "$@"

executeCallback finalization

exit 0
