#!/usr/bin/env ksh
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
SCRIPT_CACHE=${SCRIPT_DIR}/var/cache/domains
SCRIPT_CACHE_TTL=5
TIMESTAMP=`date '+%s'`

VIRSH="sudo `which virsh`"
ARGS=( "${@}" )
UUID="${1:-all}"

[ -d ${SCRIPT_CACHE} ] || mkdir -p ${SCRIPT_CACHE}

refresh_cache() {
    uuid="${1}"
    if  [[ "${uuid}" =~ ^(all|ALL|-a)$ ]]; then
        for vm_uuid in `${VIRSH} list --all --uuid`; do
            refresh_cache "${vm_uuid}"
        done
    else
        dumpxml=${SCRIPT_CACHE}/${uuid}.xml
        if [[ -f ${dumpxml} ]]; then
	    if [[ $(( `stat -c '%Y' "${dumpxml}"`+60*${SCRIPT_CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
	        ${VIRSH} dumpxml ${uuid} > ${dumpxml}
	    fi
        else
	    ${VIRSH} dumpxml ${uuid} > ${dumpxml}
        fi
        echo "${dumpxml}"
    fi
    return 0
}

Size2Bytes() {
    size=${1:-0}
    unit=${2:-KiB}
    
    [[ ${unti} =~ (B|bytes|Bytes) ]] && echo "${size:-0}" && return 0
    
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
cache=( $(refresh_cache "${UUID}") )
headers[00]="ID"
headers[01]="NAME"
headers[02]="vCPU"
headers[03]="MEMORY ALLOC"
headers[04]="MEMORY CURRENT"
headers[05]="MEMORY MAX"
headers[06]="STORAGE ALLOC"
headers[07]="STORAGE CAPACITY"
headers[08]="STORAGE PHYSICAL"
headers[09]="UUID"
headers[10]="STATUS"
for index in ${!ARGS[@]}; do
    if [[ ${ARGS[${index}]} == '--table' ]]; then
	rval[${#rval[@]}]=`printf '%s|' "${headers[@]}"`
	rval[${#rval[@]}]=`printf '%s|' "${headers[@]}" | sed -e 's/[a-zA-Z]/=/g' -e 's/ /=/g'`
	display="table"
	break
    elif [[ ${ARGS[${index}]} == '--raw' ]]; then
	display="raw"
	break
    fi
done
fields[00]='domain/@id'
fields[01]='domain/name'
fields[02]='domain/vcpu'
fields[03]='domain/memory'
fields[04]='domain/memory/@unit'
fields[05]='domain/currentMemory'
fields[06]='domain/currentMemory/@unit'
fields[07]='domain/maxMemory'
fields[08]='domain/maxMemory/@unit'
fields[09]='0'
fields[10]='0'
fields[11]='0'
fields[12]='domain/uuid'
for index in ${!fields[@]}; do
    string+="${fields[${index}]},\"|\""
    if [[ ${index}+1 -lt ${#fields[@]} ]]; then
        string+=','
    fi
done
for index in ${!cache[@]}; do
    IFS_DEFAULT="${IFS}"
    IFS='|' data=(`xmlstarlet sel -q -T -t -v "concat(${string})" \
                   -n ${cache[${index}]} 2>/dev/null`)
    IFS="${IFS_DEFAULT}"
    disks=`xmlstarlet sel -q -T -t -m "//domain/devices/disk[@device='disk']/target/@dev" \
	       -v . -n ${cache[${index}]} 2>/dev/null`
    data[03]=$( Size2Bytes "${data[03]}" "${data[04]}" )
    unset data[04]
    data[05]=$( Size2Bytes "${data[05]}" "${data[06]}" )
    unset data[06]
    data[07]=$( Size2Bytes "${data[07]}" "${data[08]}" )
    unset data[08]
    for d in ${disks}; do
        storage_raw=`${VIRSH} domblkinfo ${data[12]} ${d} 2>/dev/null`
	storage_alloc=`echo "${storage_raw}" | grep 'Allocation:' | awk -F: '{print $2}'`
	storage_capac=`echo "${storage_raw}" | grep 'Capacity:' | awk -F: '{print $2}'`
	storage_physi=`echo "${storage_raw}" | grep 'Physical:' | awk -F: '{print $2}'`
	data[09]=$(( ${data[09]}+${storage_alloc:-0} ))
	data[10]=$(( ${data[10]}+${storage_capac:-0} ))
	data[11]=$(( ${data[11]}+${storage_physi:-0} ))
    done
    data[13]=`${VIRSH} domstate ${data[12]}`

    rval[${#rval[@]}]=` printf '%s|' "${data[@]}"`

    total[01]=$(( ${total[01]:-0}+1 ))
    total[02]=$(( ${total[02]:-0}+${data[02]} ))
    total[03]=$(( ${total[03]:-0}+${data[03]} ))
    total[05]=$(( ${total[05]:-0}+${data[05]} ))
    total[07]=$(( ${total[07]:-0}+${data[07]} ))
    total[09]=$(( ${total[09]:-0}+${data[09]} ))
    total[10]=$(( ${total[10]:-0}+${data[10]} ))
    total[11]=$(( ${total[11]:-0}+${data[11]} ))
done

if [[ ${display} == 'table' ]]; then
    total[00]='TOTAL'
    rval[${#rval[@]}]=`printf '%s|' "${headers[@]}" | sed -e 's/[a-zA-Z]/=/g' -e 's/ /=/g'`
    rval[${#rval[@]}]=`printf '%s|' "${total[@]}"`
    printf '%s\n' "${rval[@]}" | sed 's/\t/,|,/g' | column -s '|' -t
elif [[ ${display} == 'json' ]]; then
    json_raw='{ "domains": [ '
    for dom in ${!rval[@]}; do
	IFS_DEFAULT="${IFS}"
	IFS='|' raw=( ${rval[${dom}]} )
	IFS="${IFS_DEFAULT}"

	json_raw+='{'
	for idx in ${!headers[@]}; do
	    key=`echo "${headers[${idx}]}" | awk '{gsub(/ /,"_",$0); print tolower($0)}'`
	    json_raw+="\"${key}\": \"${raw[${idx}]}\","
	done
	json_raw="${json_raw%?}},"
    done
    json_raw="${json_raw%?} ]}"
    echo "${json_raw}" | jq '.domains'
else
    printf '%s\n' "${rval[@]}"
fi
exit 0
