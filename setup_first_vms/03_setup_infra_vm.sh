#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME
Doit être exécuté sur le serveur d'infrastructure : $infra_hostname
"

info "Running : $ME $*"

typeset -r hn=$(hostname -s)
if [ "$hn" != "$infra_hostname" ]
then
	error "hostname is $hn, want $infra_hostname"
	exit 1
fi

line_separator
info "Update OS"
test_if_rpm_update_available
[ $? -eq 0 ] && exec_cmd yum -y update || true
LN

line_separator
exec_cmd yum -y install nfs-utils git targetcli deltarpm chrony wget net-tools vim-enhanced unzip tmux deltarpm createrepo psmisc
LN

line_separator
exec_cmd "sysctl -w net.ipv4.ip_forward=1"
exec_cmd "echo \"net.ipv4.ip_forward = 1\" >> /etc/sysctl.d/ip_forward.conf"
exec_cmd "firewall-cmd --permanent --direct --passthrough ipv4 -t nat -I POSTROUTING -o $if_net_name -j MASQUERADE -s ${infra_network}.0/24"
exec_cmd "firewall-cmd --reload"
LN

line_separator
info "Activation des services NFS serveur."
exec_cmd "systemctl enable rpcbind"
exec_cmd "systemctl start rpcbind"
LN

exec_cmd "systemctl enable nfs-server"
exec_cmd "systemctl start nfs-server"
LN

info "Ajoute nfs dans la zone 'trusted'"
exec_cmd "firewall-cmd --add-service=nfs --permanent --zone=trusted"
exec_cmd "firewall-cmd --reload"
LN

line_separator
case $type_shared_fs in
	nfs)
		exec_cmd "echo \"$client_hostname:/home/$common_user_name/plescripts /mnt/plescripts nfs rw,$nfs_options,async,comment=systemd.automount\"  >> /etc/fstab"
		LN
		;;

	vbox)
		exec_cmd "echo \"plescripts  /mnt/plescripts     vboxsf defaults,uid=$common_user_name,gid=users,_netdev 0 0\" >> /etc/fstab"
		LN
		;;
esac

line_separator
info "Création du VG asm01 sur le disque sdb"
exec_cmd "~/plescripts/san/create_vg.sh -device=sdb -vg=asm01"
LN

line_separator
info "Configure SAN"
exec_cmd "~/plescripts/san/targetcli_default_cfg.sh"
LN

exec_cmd ~/plescripts/ntp/config_ntp.sh -role=infra

exec_cmd ~/plescripts/gadgets/install.sh infra

line_separator
info "Configure DNS"
exec_cmd "~/plescripts/dns/install/01_install_bind.sh"
exec_cmd "~/plescripts/dns/install/03_configure.sh"

exec_cmd "~/plescripts/dns/add_server_2_dns.sh -name=$client_hostname -ip_node=1"
exec_cmd "~/plescripts/dns/add_server_2_dns.sh -name=$master_name -ip_node=$master_ip_node"
exec_cmd "~/plescripts/dns/show_dns.sh"
