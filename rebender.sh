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
    if isValidModule "$MODULE"; then
        echo "Usage: $0 $FULL_CONFIG $MODULE (action) ..."
        echo
        if [ -z "$CONFIG" ]; then
            configUsage
        fi
        moduleUsage "$MODULE"
    else
        echo "Usage: $0 ${FULL_CONFIG:-(config)} (sub-module) (action) ..."
        echo
        if [ -z "$CONFIG" ]; then
            configUsage
        fi
        modulesUsage
    fi
}

# Startup...
modulesLoad
loadConfig "$1" || (echo; usage; exit 1)

MODULE="$2"

[ $# -lt 3 ] && (usage; exit 1)

ACTION="$3"

if isRemote && ! module_isLocalAction "$MODULE" "$ACTION"; then
    runOnRemote "$@"
    EXIT_CODE=$?
    exit $EXIT_CODE
fi

shift 3

moduleCheckConfig "$MODULE" "$@"
moduleAction "$MODULE" "$ACTION" "$@"

exit 0
