#!/usr/bin/env ksh

VIRSH="`which virsh`"
for net in `${VIRSH} net-list --all --uuid | sort | uniq`; do
    output=""
    ${VIRSH} net-info ${net} | while read line; do
       key=`echo ${line}|awk -F: '{print $1}'|awk '{$1=$1};1'`
       val=`echo ${line}|awk -F: '{print $2}'|awk '{$1=$1};1'`
       if [[ ${key} =~ ^(Id|Name|UUID|Active|Bridge)$ ]]; then
          output+="`echo ${line}|awk -F: '{print $2}'|awk '{$1=$1};1'`|"
       fi
    done
    echo ${output}|sed 's/.$//'
done
