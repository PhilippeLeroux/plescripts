#!/bin/bash
# vim: ts=4:sw=4:ft=sh
# ft=sh car la colorisation ne fonctionne pas si le nom du script commence par
# un n°

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME

Doit être exécuté sur le serveur d'infrastructure : $infra_hostname
"

# Fixé en dur bug aléatoire.
typeset -r nm_workaround=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exec_cmd "$HOME/plescripts/grub2/enable_kernel.sh -version=$infra_kernel_version"

if [ $kernel_kpti == disable ]
then
	info "Disable KPTI"
	exec_cmd '~/plescripts/grub2/setup_kernel_boot_options.sh -add="nopti"'
	LN
fi

line_separator
#	Le serveur sert de gateway sur internet.
#	https://www.centos.org/forums/viewtopic.php?t=53819
exec_cmd "sysctl -w net.ipv4.ip_forward=1"
exec_cmd "echo \"net.ipv4.ip_forward = 1\" >> /etc/sysctl.d/ip_forward.conf"
exec_cmd firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0	\
					-o $if_net_name -j MASQUERADE

exec_cmd firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0		\
					-i $if_pub_name -o $if_net_name -j ACCEPT

exec_cmd firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0		\
					-i $if_net_name -o $if_pub_name -m state					\
					--state RELATED,ESTABLISHED -j ACCEPT

exec_cmd firewall-cmd --reload
LN

line_separator
info "Enable & start NFS services"
exec_cmd "systemctl enable rpcbind"
exec_cmd "systemctl start rpcbind"
LN

exec_cmd "systemctl enable nfs-server"
exec_cmd "systemctl start nfs-server"
LN

info "Add NFS to trusted zone"
exec_cmd "firewall-cmd --add-service=nfs --permanent --zone=trusted"
exec_cmd "firewall-cmd --reload"
LN

line_separator
exec_cmd "echo \"$client_hostname:/home/$common_user_name/plescripts /mnt/plescripts nfs rw,$rw_nfs_options,comment=systemd.automount\"  >> /etc/fstab"
LN

[ $disks_hosted_by == san ] && ~/plescripts/san/setup_targetcli.sh || true

# Par défaut le serveur NTP est chrony, je le garde pour le serveur d'infra.
exec_cmd ~/plescripts/ntp/configure_chrony.sh -role=infra
LN

exec_cmd ~/plescripts/gadgets/customize_logon.sh -name=$infra_hostname

line_separator
info "Setup DNS and DHCP."
exec_cmd "~/plescripts/dns/install/install_dhcp_and_bind.sh"
exec_cmd "~/plescripts/dns/install/setup_dhcp_and_bind.sh"

exec_cmd ~/plescripts/dns/add_server_2_dns.sh	-name=$client_hostname		\
												-ip_node=1

exec_cmd ~/plescripts/dns/add_server_2_dns.sh	-name=$master_hostname		\
												-ip_node=$master_ip_node

exec_cmd ~/plescripts/dns/show_dns.sh
LN

if [ $nm_workaround == yes ]
then
	exec_cmd ~/plescripts/nm_workaround/create_service.sh -role=infra
	LN
fi

exec_cmd ~/plescripts/journald/enable_persistent_storage_for_syslog.sh

LN
