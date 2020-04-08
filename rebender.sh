#!/bin/bash
SCRIPT_FILENAME=$(readlink -f "`cd \`dirname \"$0\"\`; pwd`/`basename \"$0\"`")
SCRIPT_ROOT=$(dirname "$SCRIPT_FILENAME")
cd "$SCRIPT_ROOT"

set -e -o pipefail
source "includes/common.inc.sh"
source "includes/configs.inc.sh"
source "includes/modules.inc.sh"
source "includes/remote.inc.sh"

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
        echo "Usage: $0 ${FULL_CONFIG:-(config)} (sub-module) (action) ..."
        echo
        if [ -z "$CONFIG" ]; then
            configs_usage
        fi
        modules_usage
    fi
}

# Startup...
modules_load
config_load "$1" || (echo; usage; exit 1)

MODULE="$2"

[ $# -lt 3 ] && (usage; exit 1)

remote_sshAgent

ACTION="$3"
if remote_isRequested && ! module_action_isLocal "$MODULE" "$ACTION"; then
    remote_pushAppConfig

    info "Running config remotely..."
    remote_run "$@"
    EXIT_CODE=$?
    exit $EXIT_CODE
fi

info "Running config locally..."
shift 3

module_checkConfig "$MODULE" "$@"
module_action "$MODULE" "$ACTION" "$@"

exit 0
