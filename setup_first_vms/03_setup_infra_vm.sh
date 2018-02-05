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

if [ "$infra_kernel_version" == redhat ]
then
	exec_cmd "~/plescripts/grub2/enable_redhat_kernel.sh -skip_test_infra"
	LN
else
	exec_cmd "~/plescripts/grub2/enable_oracle_kernel.sh -version=$infra_kernel_version"
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

if [ $disks_hosted_by == san ]
then
	if [ 0 -eq 1 ]
	then # Les tests ont montré plus d'erreurs avec cette préco appliquée.
	line_separator
	info "Update lvm conf (Datera preco)"
	exec_cmd 'sed -i "s/write_cache_state =.*/write_cache_state = 0/" /etc/lvm/lvm.conf'
	exec_cmd 'sed -i "s/readahead =.*/readahead = \"none\"/" /etc/lvm/lvm.conf'
	LN
	fi # [ 0 -eq 1 ]

	line_separator
	info "Create VG $infra_vg_name_for_db_luns on first unused disk :"
	exec_cmd ~/plescripts/san/create_vg.sh					\
							-device=auto					\
							-vg=$infra_vg_name_for_db_luns	\
							-add_partition=no				\
							-io_scheduler=cfq
	LN

	line_separator
	info "Setup SAN"
	exec_cmd "~/plescripts/san/targetcli_default_cfg.sh"
	LN

	line_separator
	info "Workaround target error"
	exec_cmd cp ~/plescripts/setup_first_vms/check-target.service	\
				/usr/lib/systemd/system/check-target.service
	exec_cmd systemctl enable check-target.service
	LN
fi

#	Le serveur d'infra doit utiliser chrony, ntp merde trop
exec_cmd ~/plescripts/ntp/configure_chrony.sh -role=infra
LN

exec_cmd ~/plescripts/gadgets/customize_logon.sh -name=$infra_hostname

line_separator
info "Configure DNS"
exec_cmd "~/plescripts/dns/install/01_install_bind.sh"
exec_cmd "~/plescripts/dns/install/03_configure.sh"

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
