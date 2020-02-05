#!/usr/bin/env ksh
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
SCRIPT_CACHE=${SCRIPT_DIR}/var/cache
SCRIPT_CACHE_TTL=5
SCRIPT_DATA=${SCRIPT_DIR}/var/data
SCRIPT_DATA_TTL=5
SCRIPT_DATA_FILE=${SCRIPT_DATA}/domains.json
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

keys[00]='id|/domain/@id'
keys[01]='name|/domain/name'
keys[02]='vcpu|/domain/vcpu'
keys[03]='memory|/domain/memory'
keys[04]='memory_unit|/domain/memory/@unit'
keys[05]='memory_current|/domain/currentMemory'
keys[06]='memory_current_unit|/domain/currentMemory/@unit'
keys[07]='memory_max|/domain/maxMemory'
keys[08]='memory_max_unit|/domain/maxMemory/@unit'
keys[09]='storage_alloc|0'
keys[10]='storage_capacity|0'
keys[11]='storage_physical|0'
keys[12]='uuid|/domain/uuid'
keys[13]='status|0'
keys[14]='autostart|0'
keys[15]='persistent|0'

for idx in ${!keys[@]}; do
    xmlvalue=`echo "${keys[${idx}]}" | awk -F'|' '{print $2}'`
    string+="${xmlvalue},\"|\","
done
string="${string%?}"

doms_xml=( $(refresh_cache_domains "${UUID}") )
for index in ${!doms_xml[@]}; do
    IFS='|' data=(`xmlstarlet sel -q -T -t -v "concat(${string})" \
                   -n ${doms_xml[${index}]} 2>/dev/null`)
    IFS="${IFS_DEFAULT}"
    disks=`xmlstarlet sel -q -T -t -m "//domain/devices/disk[@device='disk']/target/@dev" \
	       -v . -n ${doms_xml[${index}]} 2>/dev/null`
    data[03]=$( Size2Bytes "${data[03]}" "${data[04]}" )
    data[05]=$( Size2Bytes "${data[05]}" "${data[06]}" )
    data[07]=$( Size2Bytes "${data[07]}" "${data[08]}" )
    for d in ${disks}; do
        storage_raw=`${VIRSH} domblkinfo ${data[12]} ${d} 2>/dev/null`
	storage_alloc=`echo "${storage_raw}" | grep 'Allocation:' | awk -F: '{print $2}'`
	storage_capac=`echo "${storage_raw}" | grep 'Capacity:' | awk -F: '{print $2}'`
	storage_physi=`echo "${storage_raw}" | grep 'Physical:' | awk -F: '{print $2}'`
	data[09]=$(( ${data[09]}+${storage_alloc:-0} ))
	data[10]=$(( ${data[10]}+${storage_capac:-0} ))
	data[11]=$(( ${data[11]}+${storage_physi:-0} ))
    done
    dominfo=`${VIRSH} dominfo ${data[12]} 2>/dev/null`
    data[13]=`echo "${dominfo}" | grep -E "^State:" | awk -F':' '{print $2}' | awk '{$1=$1};1'`
    data[14]=`echo "${dominfo}" | grep -E "^Autostart:" | awk -F':' '{print $2}' | awk '{$1=$1};1'`
    data[15]=`echo "${dominfo}" | grep -E "^Persistent:" | awk -F':' '{print $2}' | awk '{$1=$1};1'`
    
    rval[${#rval[@]}]=` printf '%s|' "${data[@]}"`
done

json_raw='{ "domains": [ '
for dom in ${!rval[@]}; do
    IFS='|' raw=( ${rval[${dom}]} )
    IFS="${IFS_DEFAULT}"

    json_raw+='{ '
    for idx in ${!keys[@]}; do
	attr=`echo "${keys[${idx}]}" | awk -F'|' '{print $1}'`	
	[[ ${attr} =~ ^(.*_unit)$ ]] && continue
	
	json_raw+="\"${attr}\": \"${raw[${idx}]}\","
    done
    json_raw="${json_raw%?}},"
done
json_raw="${json_raw%?} ] }"
echo "${json_raw}" > ${SCRIPT_DATA_FILE}

if [[ ${TYPE} == 'json' ]]; then
    jq '.domains' ${SCRIPT_DATA_FILE} 2>/dev/null
else
    echo ${SCRIPT_DATA_FILE}
fi
exit 0
