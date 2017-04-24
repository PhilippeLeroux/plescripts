#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

must_be_executed_on_server "$master_hostname"

#	Ce script doit être exécuté uniquement si le serveur d'infra existe.

line_separator
exec_cmd nmcli connection show
# xargs supprimme les éventuelles espaces de début et/ou de fin.
conn_name="$(nmcli connection show | grep $if_pub_name | cut -d\  -f1-2 | xargs)"
info "Connection name : $conn_name"
info "Update Iface $if_pub_name :"
#	Le serveur sera cloné, il ne faut donc pas d'adresse mac ou d'uuid de définie.
exec_cmd nmcli connection modify		"'$conn_name'"				\
				ipv4.method				manual						\
				ipv4.addresses			$master_ip/$if_pub_prefix	\
				ipv4.dns				$dns_ip						\
				connection.zone			trusted						\
				connection.autoconnect	yes
LN
exec_cmd "sed -i 's/^NAME=.*/NAME=$if_pub_name/' $network_scripts/ifcfg-$if_pub_name"
exec_cmd "sed -i '/^UUID=/d' $network_scripts/ifcfg-$if_pub_name"
exec_cmd "cat $network_scripts/ifcfg-$if_pub_name"
exec_cmd systemctl restart network
LN

line_separator
#	D'après la doc Oracle ASM fonctionne avec SELinux activé.
#	Mais dans les faits ca ne marche pas lors de l'installation d'ASM, une fois
#	ASM installé SELinux peut être activé et ASM fonctionnera.
info "Disable selinux"
update_value SELINUX disabled /etc/selinux/config
LN

line_separator
info "Disable firewall"
exec_cmd "systemctl disable firewalld"
exec_cmd "systemctl stop firewalld"
LN

line_separator
info "Setup yum repositories"
exec_cmd mkdir -p /mnt$infra_olinux_repository_path
exec_cmd "echo \"$infra_hostname:$infra_olinux_repository_path /mnt$infra_olinux_repository_path nfs ro,$ro_nfs_options,comment=systemd.automount 0 0\" >> /etc/fstab"
exec_cmd mount /mnt$infra_olinux_repository_path
LN

info "Add local repositories"
exec_cmd ~/plescripts/yum/add_local_repositories.sh -role=master
exec_cmd ~/plescripts/yum/switch_repo_to.sh	\
					-local -release=$master_yum_repository_release
LN

exec_cmd "~/plescripts/setup_first_vms/02_update_config.sh"

exec_cmd ~/plescripts/ntp/configure_chrony.sh -role=master

exec_cmd ~/plescripts/gadgets/customize_logon.sh -name=$master_hostname

line_separator
#	N'a pas d'effet si le kernel est mis à jour.
exec_cmd ~/plescripts/shell/set_plymouth_them
LN
