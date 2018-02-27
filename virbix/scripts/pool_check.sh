#!/usr/bin/env ksh

APP_DIR=$(dirname $0)
VIRSH="sudo `which virsh`"
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

if [[ ${ATTR} == 'size_used' ]]; then
    refresh_cache
    rval=`xmllint --xpath "string(//allocation)" ${CACHE_FILE}`
elif [[ ${ATTR} == 'size_free' ]]; then
    refresh_cache
    rval=`xmllint --xpath "string(//available)" ${CACHE_FILE}`
elif [[ ${ATTR} == 'state' ]]; then
    rval="`${VIRSH} pool-info ${UUID}|grep '^State:'|awk -F: '{print $2}'|awk '{$1=$1};1'`"
fi

echo ${rval:-0}
