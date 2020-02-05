#!/usr/bin/env ksh

APP_DIR=$(dirname $0)
VIRSH="`which virsh`"
UUID="${1}"
ATTR="${2}"
TIMESTAMP=`date '+%s'`
CACHE_DIR="${APP_DIR}/${CACHE_DIR:-./var/cache}/pools"
CACHE_FILE=${CACHE_DIR}/${UUID}.xml
CACHE_TTL=5

refresh_cache() {
    [ -d ${CACHE_DIR} ] || mkdir -p ${CACHE_DIR}
    if [[ -f ${CACHE_FILE} ]]; then
	if [[ $(( `stat -c '%Y' "${CACHE_FILE}"`+60*${CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
	    ${VIRSH} pool-dumpxml ${UUID} > ${CACHE_FILE}
	fi
    else
	${VIRSH} pool-dumpxml ${UUID} > ${CACHE_FILE}
    fi
}

refresh_cache
if [[ ${ATTR} == 'size_used' ]]; then
    rval=`xmllint --xpath "string(//pool/allocation)" ${CACHE_FILE}`
elif [[ ${ATTR} == 'size_free' ]]; then
    rval=`xmllint --xpath "string(//pool/available)" ${CACHE_FILE}`
elif [[ ${ATTR} == 'size_total' ]]; then
    rval=`xmllint --xpath "string(//pool/capacity)" ${CACHE_FILE}`
elif [[ ${ATTR} == 'state' ]]; then
    state="`${VIRSH} pool-info ${UUID}|grep '^State:'|awk -F: '{print $2}'|awk '{$1=$1};1'`"
    case $state in
    "running")
      rval="0"
      ;;
    "paused")
      rval="1"
      ;;
    "shut off")
      rval="2"
      ;;
    *)
      rval="3"
      ;;
    esac
fi

echo ${rval:-0}
