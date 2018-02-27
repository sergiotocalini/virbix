#!/usr/bin/env ksh

VIRSH="sudo `which virsh`"
UUID="${1}"
ATTR="${2}"

if [[ ${ATTR} == 'state' ]]; then
   ${VIRSH} domstate ${UUID}|sed '/^\s*$/d'
fi
