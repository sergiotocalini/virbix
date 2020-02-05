# virbix
Zabbix KVM Monitoring

# Dependencies
## Packages
* ksh
* xmllint

### Debian/Ubuntu

    #~ sudo apt install ksh xmllint
    #~

### Red Hat

    #~ sudo yum install ksh
    #~

# Deploy
The username and the password can be empty if jenkins has the read only option enable.
Default variables:

NAME|VALUE
----|-----
LIBVIRT_URI|qemu:///system

*Note: this variables has to be saved in the config file (virbix.conf) in the same directory than the script.*

## Zabbix

Add zabbix user in libvirt group (mandatory for running virsh command without sudo).

    #~ git clone https://github.com/sergiotocalini/virbix.git
    #~ sudo ./virbix/deploy_zabbix.sh "<LIBVIRT_URI>"
    #~ sudo systemctl restart zabbix-agent
    
*Note: the installation has to be executed on the zabbix agent host and you have to import the template on the zabbix web. The default installation directory is /etc/zabbix/scripts/agentd/virbix*
