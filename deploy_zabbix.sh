#!/usr/bin/env ksh
SOURCE_DIR=$(dirname $0)
ZABBIX_DIR=/etc/zabbix

LIBVIRT_URI=${1:-qemu:///system}

mkdir -p ${ZABBIX_DIR}/scripts/agentd/virbix
cp -r ${SOURCE_DIR}/virbix/scripts ${ZABBIX_DIR}/scripts/agentd/virbix/
cp ${SOURCE_DIR}/virbix/virbix.conf.example ${ZABBIX_DIR}/scripts/agentd/virbix/virbix.conf
cp ${SOURCE_DIR}/virbix/virbix.sh ${ZABBIX_DIR}/scripts/agentd/virbix/
cp ${SOURCE_DIR}/virbix/zabbix_agentd.conf ${ZABBIX_DIR}/zabbix_agentd.d/virbix.conf
sed -i "s/LIBVIRT_DEFAULT_URI=.*/LIBVIRT_DEFAULT_URI=\"${LIBVIRT_URI}\"/g" ${ZABBIX_DIR}/scripts/agentd/virbix/virbix.conf
