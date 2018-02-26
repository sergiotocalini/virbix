#!/usr/bin/env ksh

APP_DIR=$(dirname $0)
VIRSH="sudo `which virsh`"
UUID="${1}"
ATTR="${2}"
TIMESTAMP=`date '+%s'`
CACHE_DIR="${CACHE_DIR:-./var/cache}/pools"
CACHE_FILE=${APP_DIR}/${CACHE_DIR}/${UUID}.xml
CACHE_TTL=5

[ -d ${CACHE_DIR} ] || mkdir -p ${CACHE_DIR}

if [[ -f ${CACHE_FILE} ]]; then
   if [[ $(( `stat -c '%Y' "${CACHE_FILE}"`+60*${CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
      ${VIRSH} pool-dumpxml ${UUID} > ${CACHE_FILE}
   fi
else
   ${VIRSH} pool-dumpxml ${UUID} > ${CACHE_FILE}
fi

if [[ ${ATTR} == 'size_used' ]]; then
   rval=`xmllint --xpath "string(//allocation)" ${CACHE_FILE}`
elif [[ ${ATTR} == 'size_free' ]]; then
   rval=`xmllint --xpath "string(//available)" ${CACHE_FILE}`
fi

echo ${rval:-0}
