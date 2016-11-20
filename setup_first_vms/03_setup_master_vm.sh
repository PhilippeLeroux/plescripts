#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME
Doit être exécuté sur le serveur master.
"

script_banner $ME $*

typeset hn="$(hostname -s)"
if [ "$hn" != "$master_name" ]
then
	error "server is $hn, want $master_name"
	info "$str_usage"
	exit 1
fi
unset hn

info "Mount /mnt/plescripts"
exec_cmd -c "mount ${client_hostname}:/home/$common_user_name/plescripts /mnt/plescripts -t nfs -o rw,$nfs_options"

line_separator
info "Update Iface $if_pub_name"
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
remove_value UUID						$if_pub_file
update_value ZONE		trusted			$if_pub_file
update_value GATEWAY 	$dns_ip			$if_pub_file
LN

info "New configuration take effect."
exec_cmd systemctl restart network
LN

line_separator
info "Disable selinux"
update_value SELINUX disabled /etc/selinux/config
LN

line_separator
info "Disable firewall"
exec_cmd "systemctl disable firewalld"
exec_cmd "systemctl stop firewalld"
LN

test_if_rpm_update_available
[ $? -eq 0 ] && exec_cmd yum -y update || true
LN

line_separator
exec_cmd yum -y install nfs-utils iscsi-initiator-utils deltarpm chrony wget net-tools vim-enhanced unzip tmux deltarpm

line_separator
exec_cmd "echo \"$client_hostname:/home/$common_user_name/plescripts /mnt/plescripts nfs rw,$nfs_options,comment=systemd.automount 0 0\" >> /etc/fstab"
exec_cmd mount -a /mnt/plescripts
LN

exec_cmd ~/plescripts/ntp/config_ntp.sh -role=master

exec_cmd ~/plescripts/gadgets/install.sh master

line_separator
exec_cmd "~/plescripts/nm_workaround/rm_conn_without_device.sh"
LN

line_separator
info "Network Manager Workaround"
exec_cmd -c "~/plescripts/nm_workaround/nm_workaround.sh -role=master"
#	Plante car $if_pub_name n'existe pas, existera au reboot.
LN

line_separator
exec_cmd "~/plescripts/shell/set_plymouth_them"
LN
