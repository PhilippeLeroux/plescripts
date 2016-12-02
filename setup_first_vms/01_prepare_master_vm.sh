#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

must_be_executed_on_server "$master_name"

#	Ce script doit être exécuté uniquement si le serveur d'infra existe.

line_separator
info "Network config :"
update_value NAME		$if_pub_name	$if_pub_file
update_value DEVICE		$if_pub_name	$if_pub_file
update_value BOOTPROTO	static			$if_pub_file
update_value IPADDR		$master_ip 		$if_pub_file
update_value DNS1		$dns_ip			$if_pub_file
update_value USERCTL	no				$if_pub_file
update_value ONBOOT		yes 			$if_pub_file
update_value PREFIX		$if_pub_prefix	$if_pub_file
remove_value NETMASK					$if_pub_file
remove_value HWADDR						$if_pub_file
if_uuid=$(uuidgen $if_pub_name)
update_value UUID		$if_uuid		$if_pub_file
update_value ZONE		trusted			$if_pub_file
#update_value GATEWAY 	$dns_ip			$if_pub_file
LN
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
exec_cmd "echo \"$infra_hostname:$infra_olinux_repository_path /mnt$infra_olinux_repository_path nfs ro,defaults,comment=systemd.automount 0 0\" >> /etc/fstab"
exec_cmd mount /mnt$infra_olinux_repository_path
LN

info "Add local repositories"
exec_cmd ~/plescripts/yum/add_local_repositories.sh -role=master
exec_cmd ~/plescripts/yum/switch_repo_to.sh -local
LN

exec_cmd ~/plescripts/setup_first_vms/02_update_config.sh

exec_cmd ~/plescripts/ntp/config_ntp.sh -role=master

exec_cmd ~/plescripts/gadgets/customize_logon.sh -name=$master_name

line_separator
info "Network Manager Workaround"
exec_cmd ~/plescripts/nm_workaround/rm_conn_without_device.sh
LN
exec_cmd -c ~/plescripts/nm_workaround/create_service.sh -role=master
#	Plante car $if_pub_name n'existe pas, existera au reboot.
LN

line_separator
exec_cmd ~/plescripts/shell/set_plymouth_them
LN
