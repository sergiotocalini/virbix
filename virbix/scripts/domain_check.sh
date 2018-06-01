#!/usr/bin/env ksh

VIRSH="sudo `which virsh`"
UUID="${1}"
ATTR="${2}"

if [[ ${ATTR} == 'state' ]]; then
    ${VIRSH} domstate ${UUID}|sed '/^\s*$/d'
elif [[ ${ATTR} == 'json' ]]; then
    dump=`${VIRSH} dumpxml ${UUID}`
    memory=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/memory" -v . -n`
    memory_current=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/currentMemory" -v . -n`
    memory_max=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/maxMemory" -v . -n`
    vcpu=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/vcpu" -v . -n`
    vcpu_placement=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/vcpu/@placement" -v . -n`
    vcpu_cpuset=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/vcpu/@cpuset" -v . -n`
    vcpu_current=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/vcpu/@current" -v . -n`
    os_type=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/os/type" -v . -n`
    os_arch=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/os/type/@arch" -v . -n`
    os_machine=`echo "${xml}" | xmlstarlet sel -q -T -t -m "domain/os/type/@machine" -v . -n`
fi
