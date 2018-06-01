#!/usr/bin/env ksh
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
TIMESTAMP=`date '+%s'`

SECTION="${1:-all}"

if [[ ${SECTION} == "all" ]]; then
    node=`${SCRIPT_DIR}/node_report.sh all source`
    domains=`${SCRIPT_DIR}/domain_report.sh all source`
    pools=`${SCRIPT_DIR}/pool_report.sh all source`

    jq -s '.[0]*.[1]*.[2]' "${node}" "${domains}" "${pools}"
fi
