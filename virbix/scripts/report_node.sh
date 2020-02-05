#!/usr/bin/env ksh
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
SCRIPT_CACHE=${SCRIPT_DIR}/var/cache
SCRIPT_CACHE_TTL=5
SCRIPT_DATA=${SCRIPT_DIR}/var/data
SCRIPT_DATA_TTL=5
SCRIPT_DATA_FILE=${SCRIPT_DATA}/node.json
TIMESTAMP=`date '+%s'`

IFS_DEFAULT="${IFS}"

VIRSH="`which virsh`"
UUID="${1:-all}"
TYPE="${2:-json}"

if [ -f "${SCRIPT_DIR}/functions.sh" ]; then
    . "${SCRIPT_DIR}/functions.sh"
else
    echo "Please install the script on the plugin directory."
    exit 1
fi

[ -d "${SCRIPT_DATA}" ] || mkdir -p "${SCRIPT_DATA}"

nodeinfo=`${VIRSH} nodeinfo 2>/dev/null`
nodever=`${VIRSH} version 2>/dev/null`

typeset -A keys
typeset -A rval

keys['cpu_model']="CPU model:"
keys['cpu_count']="CPU(s):"
keys['cpu_freqs']="CPU frequency:"
keys['cpu_sockets']="CPU socket(s):"
keys['cpu_core_per_socket']="Core(s) per socket:"
keys['cpu_thread_per_core']="Thread(s) per core:"
keys['numa_cells']="NUMA cell(s):"
keys['memory_size']="Memory size:"

for idx in ${!keys[@]}; do
    rval["${idx}"]=`echo "${nodeinfo}" | grep "${keys[${idx}]}" | awk -F: '{print $2}'| awk '{$1=$1};1'`
    if [[ ${idx} =~ (memory_size) ]]; then
	rval["${idx}"]=$( Size2Bytes ${rval[${idx}][@]} )
    fi
done

version_api=`echo "${nodever}" | grep "Using API:" | awk -F: '{print $2}' | sed -e 's/ QEMU //g'`
version_hv=`echo "${nodever}" | grep "Running hypervisor" | awk -F: '{print $2}' | sed -e 's/ QEMU //g'`
rval['version_api']=`echo "${version_api}" | awk '{$1=$1};1'`
rval['version_hv']=`echo "${version_hv}" | awk '{$1=$1};1'`

json_raw='{ "node": { '
for idx in ${!rval[@]}; do
    json_raw+="\"${idx}\":\"${rval[${idx}]}\","
done
json_raw="${json_raw%?} }}"
echo "${json_raw}" > ${SCRIPT_DATA_FILE}

if [[ ${TYPE} == 'json' ]]; then
    jq '.node' ${SCRIPT_DATA_FILE} 2>/dev/null
else
    echo ${SCRIPT_DATA_FILE}
fi
exit 0
