#!/usr/bin/env ksh
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
SCRIPT_CACHE=${SCRIPT_DIR}/var/cache
SCRIPT_CACHE_TTL=5
SCRIPT_DATA=${SCRIPT_DIR}/var/data
SCRIPT_DATA_TTL=5
SCRIPT_DATA_FILE=${SCRIPT_DATA}/pools.json
TIMESTAMP=`date '+%s'`

IFS_DEFAULT="${IFS}"

VIRSH="sudo `which virsh`"
UUID="${1:-all}"
TYPE="${2:-json}"

if [ -f "${SCRIPT_DIR}/functions.sh" ]; then
    . "${SCRIPT_DIR}/functions.sh"
else
    echo "Please install the script on the plugin directory."
    exit 1
fi

[ -d "${SCRIPT_DATA}" ] || mkdir -p "${SCRIPT_DATA}"

kpool[00]="name|/pool/name"
kpool[01]="uuid|/pool/uuid"
kpool[02]="capacity|/pool/capacity"
kpool[03]="capacity_unit|/pool/capacity/@unit"
kpool[04]="allocation|/pool/allocation"
kpool[05]="allocation_unit|/pool/allocation/@unit"
kpool[06]="available|/pool/available"
kpool[07]="available_unit|/pool/available/@unit"
kpool[08]="path|/pool/target/path"
kpool[09]="status|0"
for idx in ${!kpool[@]}; do
    xmlvalue=`echo "${kpool[${idx}]}" | awk -F'|' '{print $2}'`
    pstring+="${xmlvalue},\"|\","
done
pstring="${pstring%?}"

kvols[00]="name|/volume/name"
kvols[01]="key|/volume/key"
kvols[02]="capacity|/volume/capacity"
kvols[03]="capacity_unit|/volume/capacity/@unit"
kvols[04]="allocation|/volume/allocation"
kvols[05]="allocation_unit|/volume/allocation/@unit"
kvols[06]="path|/volume/target/path"
kvols[07]="type|/volume/target/format/@type"
kvols[08]="uuid_domain|0"
for idx in ${!kvols[@]}; do
    xmlvalue=`echo "${kvols[${idx}]}" | awk -F'|' '{print $2}'`
    vstring+="${xmlvalue},\"|\","
done
vstring="${vstring%?}"

json_raw='{"pools": [ '
pools_xml=( $(refresh_cache_pools "${UUID}") )
for index in ${!pools_xml[@]}; do
    IFS='|' pdata=(`xmlstarlet sel -q -T -t -v "concat(${pstring})" \
                    -n ${pools_xml[${index}]} 2>/dev/null`)
    IFS="${IFS_DEFAULT}"
    
    pdata[02]=$( Size2Bytes "${pdata[02]}" "${pdata[03]}" )
    pdata[04]=$( Size2Bytes "${pdata[04]}" "${pdata[05]}" )
    pdata[06]=$( Size2Bytes "${pdata[06]}" "${pdata[07]}" )

    pdata[09]=`${VIRSH} pool-info ${pdata[01]} | grep "^State:" | awk '{print $2}'`
    
    json_vols="[ "
    for vol in `${VIRSH} vol-list ${pdata[01]} | egrep -v "(^-.*|^ Name.*|^$)" | awk '{print $1}'`; do
	[[ ${vol} =~ (lost\+found) ]] && continue
	volxml=$(refresh_cache_volumes "${vol}" "${pdata[01]}")
	IFS='|' vdata=(`xmlstarlet sel -q -T -t -v "concat(${vstring})" \
                        -n ${volxml} 2>/dev/null`)
	IFS="${IFS_DEFAULT}"

	vdata[02]=$( Size2Bytes "${vdata[02]}" "${vdata[03]}" )
	vdata[04]=$( Size2Bytes "${vdata[04]}" "${vdata[05]}" )
	
	vdata[08]=$( vol_domain "${vdata[06]}" )

	json_vols+='{ '
	for idx in ${!kvols[@]}; do
	    attr=`echo "${kvols[${idx}]}" | awk -F'|' '{print $1}'`	
	    [[ ${attr} =~ ^(.*_unit)$ ]] && continue
	    json_vols+="\"${attr}\":\"${vdata[${idx}]}\","
	done
	json_vols="${json_vols%?}},"
    done
    json_vols="${json_vols%?} ]"

    json_pool='{ '
    for idx in ${!kpool[@]}; do
	attr=`echo "${kpool[${idx}]}" | awk -F'|' '{print $1}'`	
	[[ ${attr} =~ ^(.*_unit)$ ]] && continue	
	json_pool+="\"${attr}\":\"${pdata[${idx}]}\","
    done
    json_pool="${json_pool}\"volumes\": ${json_vols} },"
    
    json_raw+="${json_pool}"
done
json_raw="${json_raw%?} ] }"
echo "${json_raw}" > ${SCRIPT_DATA_FILE}

if [[ ${TYPE} == 'json' ]]; then
    jq '.pools' ${SCRIPT_DATA_FILE} 2>/dev/null
else
    echo ${SCRIPT_DATA_FILE}
fi
exit 0
