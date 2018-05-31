#!/usr/bin/env ksh
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
SCRIPT_CACHE=${SCRIPT_DIR}/var/cache/pools
SCRIPT_CACHE_TTL=5
TIMESTAMP=`date '+%s'`

IFS_DEFAULT="${IFS}"

VIRSH="sudo `which virsh`"
ARGS=( "${@}" )
UUID="${1:-all}"

[ -d "${SCRIPT_CACHE}" ] || mkdir -p "${SCRIPT_CACHE}"

refresh_cache_pools() {
    uuid="${1}"
    if  [[ "${uuid}" =~ ^(all|ALL|-a)$ ]]; then
        for pname in `${VIRSH} pool-list --all | egrep -v "(^-.*|^ Name.*|^$)" | awk '{print $1}'`; do
	    [[ ${pname} =~ (libvirt|boot-scratch) ]] && continue
	    uuid=`${VIRSH} pool-info ${pname} | grep 'UUID:' | awk -F: '{print $2}'|awk '{$1=$1};1'`
	    refresh_cache_pools "${uuid}"
        done
    else
        dumpxml=${SCRIPT_CACHE}/${uuid}.xml
        if [[ -f ${dumpxml} ]]; then
	    if [[ $(( `stat -c '%Y' "${dumpxml}"`+60*${SCRIPT_CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
	        ${VIRSH} pool-dumpxml ${uuid} > ${dumpxml}
	    fi
        else
	    ${VIRSH} pool-dumpxml ${uuid} > ${dumpxml}
        fi
        echo "${dumpxml}"
    fi
    return 0
}

refresh_cache_volumes() {
    name="${1}"
    pool="${2}"

    local_cache=${SCRIPT_CACHE}/volumes/${pool}
    [ -d ${local_cache} ] || mkdir -p ${local_cache}
    
    dumpxml=${local_cache}/${name}.xml
    if [[ -f ${dumpxml} ]]; then
	if [[ $(( `stat -c '%Y' "${dumpxml}"`+60*${SCRIPT_CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
	    ${VIRSH} vol-dumpxml "${name}" "${pool}" > ${dumpxml}
	fi
    else
	${VIRSH} vol-dumpxml "${name}" "${pool}" > ${dumpxml}
    fi
    echo "${dumpxml}"
    return 0
}

Size2Bytes() {
    size=${1:-0}
    unit=${2:-KiB}
    
    [[ ${unit} =~ (B|bytes|Bytes) ]] && echo "${size:-0}" && return 0
    
    if [[ ${unit} =~ .*iB ]]; then
	table=( 'KiB' 'MiB' 'GiB' 'TiB' 'PiB' 'EiB' 'ZiB' 'YiB' )
	multi=1024
    else
	table=( 'kB' 'MB' 'GB' 'TB' 'PB' 'EB' 'ZB' 'YB' )
	multi=1000
    fi
    
    if [[ ${size} > ${multi} ]]; then
	index=0
	for u in ${!table[@]}; do
	    if [[ ${unit} == ${table[${index}]} ]]; then
		break
	    fi
	    let "index=index+1"
	done
	
	while (( ${index} >= 0 )); do
	    size=$(( ${size}*${multi} ))
	    let "index=index-1"
	done
    fi
    echo "${size:-0}"
    return 0
}

display="json"
cache=( $(refresh_cache_pools "${UUID}") )

phdrs[00]="NAME"
phdrs[01]="UUID"
phdrs[02]="CAPACITY"
phdrs[03]="ALLOCATION"
phdrs[04]="AVAILABLE"
phdrs[05]="PATH"
phdrs[06]="STATUS"

vhdrs[00]="NAME"
vhdrs[01]="KEY"
vhdrs[02]="CAPACITY"
vhdrs[03]="ALLOCATION"
vhdrs[04]="PATH"
vhdrs[05]="TYPE"
vhdrs[06]="POOL UUID"
for index in ${!ARGS[@]}; do
    if [[ ${ARGS[${index}]} == '--table' ]]; then
	rval_pool[${#rval_pool[@]}]=`printf '%s|' "${phdrs[@]}"`
	rval_pool[${#rval_pool[@]}]=`printf '%s|' "${phdrs[@]}" | sed -e 's/[a-zA-Z]/=/g' -e 's/ /=/g'`
	rval_vols[${#rval_vols[@]}]=`printf '%s|' "${vhdrs[@]}"`
	rval_vols[${#rval_vols[@]}]=`printf '%s|' "${vhdrs[@]}" | sed -e 's/[a-zA-Z]/=/g' -e 's/ /=/g'`
	display="table"
	break
    elif [[ ${ARGS[${index}]} == '--raw' ]]; then
	display="raw"
	break
    fi
done

pfields[00]='pool/name'
pfields[01]='pool/uuid'
pfields[02]='pool/capacity'
pfields[03]='pool/capacity/@unit'
pfields[04]='pool/allocation'
pfields[05]='pool/allocation/@unit'
pfields[06]='pool/available'
pfields[07]='pool/available/@unit'
pfields[08]='pool/target/path'
for index in ${!pfields[@]}; do
    pstring+="${pfields[${index}]},\"|\""
    if [[ ${index}+1 -lt ${#pfields[@]} ]]; then
        pstring+=','
    fi
done
vfields[00]='volume/name'
vfields[01]='volume/key'
vfields[02]='volume/capacity'
vfields[03]='volume/capacity/@unit'
vfields[04]='volume/allocation'
vfields[05]='volume/allocation/@unit'
vfields[06]='volume/target/path'
vfields[07]='volume/target/format/@type'
for index in ${!vfields[@]}; do
    vstring+="${vfields[${index}]},\"|\""
    if [[ ${index}+1 -lt ${#vfields[@]} ]]; then
        vstring+=','
    fi
done
for index in ${!cache[@]}; do
    IFS='|' pdata=(`xmlstarlet sel -q -T -t -v "concat(${pstring})" \
                    -n ${cache[${index}]} 2>/dev/null`)
    IFS="${IFS_DEFAULT}"

    pdata[02]=$( Size2Bytes "${pdata[02]}" "${pdata[03]}" )
    unset pdata[03]
    pdata[04]=$( Size2Bytes "${pdata[04]}" "${pdata[05]}" )
    unset pdata[05]
    pdata[06]=$( Size2Bytes "${pdata[06]}" "${pdata[07]}" )
    unset pdata[07]
    
    pdata[09]=`${VIRSH} pool-info ${pdata[01]} | grep "^State:" | awk '{print $2}'`
    
    for vol in `${VIRSH} vol-list ${pdata[01]} | egrep -v "(^-.*|^ Name.*|^$)" | awk '{print $1}'`; do
	[[ ${vol} =~ (lost\+found) ]] && continue
	volxml=$(refresh_cache_volumes "${vol}" "${pdata[01]}")
	IFS='|' vdata=(`xmlstarlet sel -q -T -t -v "concat(${vstring})" \
                        -n ${volxml} 2>/dev/null`)
	IFS="${IFS_DEFAULT}"

	vdata[02]=$( Size2Bytes "${vdata[02]}" "${vdata[03]}" )
	unset vdata[03]
	vdata[04]=$( Size2Bytes "${vdata[04]}" "${vdata[05]}" )
	unset vdata[05]
	
	vdata[09]="${pdata[01]}"
	rval_vols[${#rval_vols[@]}]=` printf '%s|' "${vdata[@]}"`
    done
    rval_pool[${#rval_pool[@]}]=` printf '%s|' "${pdata[@]}"`
done

if [[ ${display} == 'table' ]]; then
    total[00]='TOTAL'
    echo -e "\nPOOLS:\n"
    printf '%s\n' "${rval_pool[@]}" | sed 's/\t/,|,/g' | column -s '|' -t
    echo -e "\nVOLUMES:\n"
    printf '%s\n' "${rval_vols[@]}" | sed 's/\t/,|,/g' | column -s '|' -t
elif [[ ${display} == 'json' ]]; then
    json_raw='{ "pools": [ '
    for pool in ${!rval_pool[@]}; do
	IFS='|' raw=( ${rval_pool[${pool}]} )
	IFS="${IFS_DEFAULT}"	
	json_raw+='{ '
	for idx in ${!phdrs[@]}; do
	    key=`echo "${phdrs[${idx}]}" | awk '{gsub(/ /,"_",$0); print tolower($0)}'`
	    json_raw+="\"${key}\": \"${raw[${idx}]}\","
	done
	json_raw="${json_raw%?}},"
    done
    json_raw="${json_raw%?} ]}"

    json_raw2='[ '
    for vol in ${!rval_vols[@]}; do
	IFS='|' raw2=( ${rval_vols[${vol}]} )
	IFS="${IFS_DEFAULT}"	
	json_raw2+='{ '
	for idx in ${!vhdrs[@]}; do
	    key=`echo "${vhdrs[${idx}]}" | awk '{gsub(/ /,"_",$0); print tolower($0)}'`
	    json_raw2+="\"${key}\": \"${raw2[${idx}]}\","
	done
	json_raw2="${json_raw2%?}},"	
    done
    json_raw2="${json_raw2%?} ]"
    json_output=`echo "${json_raw}" | jq '.'`
    echo "${json_output}" | jq ".volumes=${json_raw2}"
else
    printf '%s\n' "${rval_pool[@]}"
    echo ""
    printf '%s\n' "${rval_vols[@]}"
fi
exit 0
