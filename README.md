# virbix
KVM Monitoring

This script is part of a monitoring solution that allows to monitor several
services and applications.

For more information about this monitoring solution please check out this post
on my [site](https://sergiotocalini.github.io/project/monitoring).

# Dependencies
## Packages
* ksh
* xmllint

### Debian/Ubuntu

``` bash
~# sudo apt install ksh xmllint
~#
```
### Red Hat

```bash
~# sudo yum install ksh
~#
```

# Deploy
Default variables:

NAME|VALUE
----|-----
LIBVIRT_URI|qemu:///system

*__Note:__ these variables has to be saved in the config file (virbix.conf) in
the same directory than the script.*

## Zabbix

``` bash
~# git clone https://github.com/sergiotocalini/virbix.git
~# sudo ./virbix/deploy_zabbix.sh -u "qemu:///system"
~# sudo systemctl restart zabbix-agent
```
*__Note:__ the installation has to be executed on the zabbix agent host and you have
to import the template on the zabbix web. The default installation directory is
/etc/zabbix/scripts/agentd/virbix*

# Usage

```bash
~# /etc/zabbix/scripts/agentd/virbix/virbix.sh -s domain_list -j DOMID:DOMNAME:DOMUUID:DOMTYPE:DOMSTATE
{
   ...
}
~#
```
