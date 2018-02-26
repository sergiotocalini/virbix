#!/usr/bin/env ksh
for vm in `virsh list --all --uuid`; do
    output=""
    virsh dominfo ${vm} | while read line; do
       key=`echo ${line}|awk -F: '{print $1}'|awk '{$1=$1};1'`
       val=`echo ${line}|awk -F: '{print $2}'|awk '{$1=$1};1'`
       if [[ ${key} =~ ^(Id|Name|UUID|OS Type|State)$ ]]; then
          output+="`echo ${line}|awk -F: '{print $2}'|awk '{$1=$1};1'`|"
       fi
    done
    echo ${output}|sed 's/.$//'
done
