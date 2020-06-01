#!/usr/bin/env ksh
rcode=0
PATH=/usr/local/bin:${PATH}

#################################################################################

#################################################################################
#
#  Variable Definition
# ---------------------
#
APP_NAME=$(basename $0)
APP_DIR=$(dirname $0)
APP_VER="0.0.1"
APP_WEB="https://sergiotocalini.github.io/"
APP_FIX="https://github.com/sergiotocalini/virbix/issues"
#
#################################################################################

#################################################################################
#
#  Load Environment
# ------------------
#
[[ -f ${APP_DIR}/${APP_NAME%.*}.conf ]] && . ${APP_DIR}/${APP_NAME%.*}.conf

#
#################################################################################

#################################################################################
#
#  Function Definition
# ---------------------
#
usage() {
    echo "Usage: ${APP_NAME%.*} [Options]"
    echo ""
    echo "Options:"
    echo "  -a            Query arguments."
    echo "  -h            Displays this help message."
    echo "  -j            Jsonify output."
    echo "  -s ARG(str)   Script to be executed."
    echo "  -v            Show the script version."
    echo ""
    echo "Example:"
    echo "  ~# ${APP_NAME} -s domain_list"
    echo ""
    echo "Please send any bug reports to ${APP_FIX}"
    exit 1
}

version() {
    echo "${APP_NAME%.*} ${APP_VER}"
    exit 1
}

zabbix_not_support() {
    echo "ZBX_NOTSUPPORTED"
    echo ""
    usage
}

#
#################################################################################

#################################################################################
while getopts ":a:s::a:s:uphvj:" OPTION; do
    case ${OPTION} in
	a)
	    ARGS[${#ARGS[*]}]=${OPTARG//p=}
	    ;;
	h)
	    usage
	    ;;
        j)
            JSON=1
            IFS=":" JSON_ATTR=(${OPTARG//p=})
            ;;
	s)
	    SCRIPT="${APP_DIR}/scripts/${OPTARG}"
	    ;;
	v)
	    version
	    ;;
         \?)
            exit 1
            ;;
    esac
done

[[ -f "${SCRIPT%.sh}.sh" ]] || zabbix_not_support

rval=`${SCRIPT%.sh}.sh ${ARGS[@]} 2>/dev/null`
rcode="${?}"
if [[ ${JSON} -eq 1 ]]; then
    echo '{'
    echo '   "data":['
    count=1
    while read line; do
        IFS="|" values=(${line})
        output='{ '
        for val_index in ${!values[*]}; do
            output+='"'{#${JSON_ATTR[${val_index}]:-${val_index}}}'":"'${values[${val_index}]}'"'
            if (( ${val_index}+1 < ${#values[*]} )); then
                output="${output}, "
            fi
        done 
        output+=' }'
        if (( ${count} < `echo ${rval}|wc -l` )); then
            output="${output},"
        fi
        echo "      ${output}"
        let "count=count+1"
    done <<< ${rval}
    echo '   ]'
    echo '}'
else
    echo "${rval:-0}"
fi

exit ${rcode}
