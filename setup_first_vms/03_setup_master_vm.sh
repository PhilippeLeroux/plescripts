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

info "Running : $ME $*"

typeset argv
[ "$DEBUG_MODE" == "ENABLE" ] && argv="-c"

typeset hn="$(hostname -s)"
if [ "$hn" != "$master_name" ]
then
	error "server is $hn, want $master_name"
	info "$str_usage"
	exit 1
fi
unset hn

info "Montage des scripts plescripts de $client_hostname sur /mnt/plescripts"
case $type_shared_fs in
	vbox)
		exec_cmd -c "mount -t vboxsf plescripts /mnt/plescripts"
		;;

	nfs)
		exec_cmd -c "mount ${client_hostname}:/home/$common_user_name/plescripts /mnt/plescripts -t nfs -o rw,$nfs_options"
		;;
esac

line_separator
info "Mise à jour de l'Iface $if_pub_name"
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

line_separator
info "Mise à jour de l'Iface $if_priv_name"
typeset -r ip_priv=${if_priv_network}.${master_ip_node}
update_value BOOTPROTO	static			$if_priv_file
update_value IPADDR		$ip_priv		$if_priv_file
update_value USERCTL	no				$if_priv_file
update_value ONBOOT		yes 			$if_priv_file
update_value PREFIX		$if_priv_prefix	$if_priv_file
update_value MTU		9000			$if_priv_file
remove_value NETMASK					$if_priv_file
remove_value HWADDR						$if_priv_file
remove_value UUID						$if_priv_file
update_value ZONE		trusted			$if_priv_file
LN

info "Prise en compte de la nouvelle configuration."
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

line_separator
exec_cmd yum -y install nfs-utils iscsi-initiator-utils deltarpm chrony wget net-tools vim-enhanced unzip tmux deltarpm

case $type_shared_fs in
	nfs)
		line_separator
		exec_cmd "echo \"$client_hostname:/home/$common_user_name/plescripts /mnt/plescripts nfs rw,$nfs_options,comment=systemd.automount 0 0\" >> /etc/fstab"
		exec_cmd $argv mount -a /mnt/plescripts
		LN
	;;

	vbox)
		line_separator
		exec_cmd "echo \"plescripts /mnt/plescripts vboxsf defaults,uid=kangs,gid=users,_netdev 0 0\" >> /etc/fstab"
		exec_cmd $argv mount -a /mnt/plescripts
		LN
	;;
esac

exec_cmd ~/plescripts/ntp/config_ntp.sh -role=master

exec_cmd ~/plescripts/gadgets/install.sh master

line_separator
info "Désactive le dépôt du net."
typeset -ri last_line=$(wc -l /etc/yum.repos.d/public-yum-ol7.repo | cut -d' ' -f1)
exec_cmd sed -i "${last_line}s/enabled=1/enabled=0/" /etc/yum.repos.d/public-yum-ol7.repo
LN

line_separator
exec_cmd "~/plescripts/shell/set_plymouth_them"
LN
