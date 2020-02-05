#!/usr/bin/env ksh

VIRSH="`which virsh`"
for vm in `${VIRSH} pool-list --all | egrep -v "(^-.*|^ Name.*|^$)" | awk '{print $1}' | sort | uniq`; do
    output=""
    ${VIRSH} pool-info ${vm} | while read line; do
       key=`echo ${line}|awk -F: '{print $1}'|awk '{$1=$1};1'`
       val=`echo ${line}|awk -F: '{print $2}'|awk '{$1=$1};1'`
       if [[ ${key} =~ ^(Id|Name|UUID|State)$ ]]; then
          output+="`echo ${line}|awk -F: '{print $2}'|awk '{$1=$1};1'`|"
       fi
    done
    echo ${output}|sed 's/.$//'
done
