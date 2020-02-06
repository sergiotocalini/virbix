#!/usr/bin/env ksh

VIRSH="`which virsh`"
for vm in `${VIRSH} list --all --uuid | sort | uniq`; do
    output=""
    ${VIRSH} dominfo ${vm} | while read line; do
       key=`echo ${line}|awk -F: '{print $1}'|awk '{$1=$1};1'`
       val=`echo ${line}|awk -F: '{print $2}'|awk '{$1=$1};1'`
       if [[ ${key} =~ ^(Id|Name|UUID|OS Type|State)$ ]]; then
          output+="`echo ${line}|awk -F: '{print $2}'|awk '{$1=$1};1'`|"
       fi
    done
    echo ${output}|sed 's/.$//'
done
