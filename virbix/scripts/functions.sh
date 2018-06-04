#!/usr/bin/env ksh

refresh_cache_domains() {
    uuid="${1}"
    
    cachedir=${SCRIPT_CACHE}/domains
    [ -d "${cachedir}" ] || mkdir -p "${cachedir}"	

    if  [[ "${uuid}" =~ ^(all|ALL|-a)$ ]]; then
        for vm_uuid in `${VIRSH} list --all --uuid`; do
            refresh_cache_domains "${vm_uuid}"
        done
    else
        dumpxml=${cachedir}/${uuid}.xml
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

refresh_cache_pools() {
    uuid="${1}"

    cachedir=${SCRIPT_CACHE}/pools
    [ -d "${cachedir}" ] || mkdir -p "${cachedir}"

    if  [[ "${uuid}" =~ ^(all|ALL|-a)$ ]]; then
        for pname in `${VIRSH} pool-list --all | egrep -v "(^-.*|^ Name.*|^$)" | awk '{print $1}'`; do
	    [[ ${pname} =~ (libvirt|boot-scratch) ]] && continue
	    uuid=`${VIRSH} pool-info ${pname} | grep 'UUID:' | awk -F: '{print $2}'|awk '{$1=$1};1'`
	    refresh_cache_pools "${uuid}"
        done
    else
        dumpxml=${cachedir}/${uuid}.xml
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

    cachedir=${SCRIPT_CACHE}/pools/volumes/${pool}
    [ -d "${cachedir}" ] || mkdir -p "${cachedir}"
    
    dumpxml=${cachedir}/${name}.xml
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

vol_domain() {
    path="${1}"
    
    cache=( $(refresh_cache_domains all) )
    for index in ${!cache[@]}; do
	rval=`xmlstarlet sel -q -T -t \
              -m "/domain/devices/disk[@device='disk']/source[@file='${path}']" \
              -v '/domain/uuid' -n ${cache[${index}]}`
	[[ -n ${rval} ]] && break
    done
    echo "${rval:-0}"
}

Size2Bytes() {
    size=${1:-0}
    unit=${2:-KiB}
    
    [[ ${unit} =~ ^(B|bytes|Bytes)$ ]] && echo "${size:-0}" && return 0
    
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
