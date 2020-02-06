#!/usr/bin/env ksh

APP_DIR=$(dirname $0)
VIRSH="`which virsh`"
UUID="${1}"
ATTR="${2}"
TIMESTAMP=`date '+%s'`
CACHE_DIR="${APP_DIR}/${CACHE_DIR:-./var/cache}/net"
CACHE_FILE=${CACHE_DIR}/${UUID}.xml
CACHE_TTL=5

refresh_cache() {
    [ -d ${CACHE_DIR} ] || mkdir -p ${CACHE_DIR}
    if [[ -f ${CACHE_FILE} ]]; then
	if [[ $(( `stat -c '%Y' "${CACHE_FILE}"`+60*${CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
	    ${VIRSH} net-dumpxml ${UUID} > ${CACHE_FILE}
	fi
    else
	${VIRSH} net-dumpxml ${UUID} > ${CACHE_FILE}
    fi
}

if [[ ${ATTR} == 'bridge_name' ]]; then
    refresh_cache
    rval=`xmllint --xpath "string(//network/bridge/@name)" ${CACHE_FILE}`
elif [[ ${ATTR} == 'mac_addr' ]]; then
    refresh_cache
    rval=`xmllint --xpath "string(//network/mac/@address)" ${CACHE_FILE}`
elif [[ ${ATTR} == 'active' ]]; then
    activate="`${VIRSH} net-info ${UUID}|grep '^Active:'|awk -F: '{print $2}'|awk '{$1=$1};1'`"
    case $activate in
    "no")
      rval="0"
      ;;
    "yes")
      rval="1"
      ;;
    *)
      rval="2"
      ;;
    esac
fi

echo ${rval:-0}
