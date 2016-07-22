#!/bin/bash
#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -role=infra|master
Doit être exécuté sur le serveur d'infrastructure ou le master.
"

typeset role=undef

while [ $# -ne 0 ]
do
	case $1 in
		-role=*)
			role=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef role	"infra master"	"$str_usage"
exit_if_param_undef ip_node					"$str_usage"

typeset ip_pub
typeset ip_priv

case $role in
	infra)
		echo "${infra_hostname}.${infra_domain}" > /etc/hostname
		ip_pub=${infra_network}.${infra_ip_node}
		ip_priv=${if_priv_network}.${infra_ip_node}

		if [ ! -f ~/.bashrc_extensions ]
		then
			exec_cmd "cp ~/plescripts/myconfig/bashrc_extensions ~/.bashrc_extensions"
			cat << EOS >> ~/.bashrc
[ -f ~/.bashrc_extensions ] && . ~/.bashrc_extensions || true
if [ -t 0 ]
then
	count_lv_error=\$(lvs 2>/dev/null| grep -E "*asm01 .*\-a\-.*$" | wc -l)

	if [ \$count_lv_error -ne 0 ]
	then
		echo -e "\${RED}\$count_lv_error lvs errors : poweroff + start !\${NORM}"
		systemctl status target -l
	else
		echo -e "\${GREEN}lvs OK\${NORM}"
	fi
fi
EOS
		fi
		;;

	master)
		ip_pub=${infra_network}.${master_ip_node}
		ip_priv=${if_priv_network}.${master_ip_node}
		;;

	*)
		error "-role invalid."
		LN
		info "$str_usage"
		exit 1
esac

info "Rôle du serveur $role"
info "	IP public  : $ip_pub"
info "	IP private : $ip_priv"
info "	DNS        : $dns_ip"
LN

line_separator
info "Create user $common_user_name"
exec_cmd -c "useradd -g users -M -N -u 1000 $common_user_name"
LN

case $role in
	master)
		line_separator
		update_value BOOTPROTO	static			$if_pub_file
		update_value IPADDR		$ip_pub 		$if_pub_file
		update_value DNS1		$dns_ip			$if_pub_file
		update_value USERCTL	no				$if_pub_file
		update_value ONBOOT		yes 			$if_pub_file
		update_value PREFIX		24				$if_pub_file
		remove_value NETMASK					$if_pub_file
		remove_value HWADDR						$if_pub_file
		remove_value UUID						$if_pub_file
		update_value ZONE		trusted			$if_pub_file
		update_value GATEWAY 	$dns_ip			$if_pub_file
		LN

		line_separator
		update_value BOOTPROTO	static			$if_priv_file
		update_value IPADDR		$ip_priv		$if_priv_file
		update_value USERCTL	no				$if_priv_file
		update_value ONBOOT		yes 			$if_priv_file
		update_value PREFIX		24				$if_priv_file
		update_value MTU		9000			$if_priv_file
		remove_value NETMASK					$if_priv_file
		remove_value HWADDR						$if_priv_file
		remove_value UUID						$if_priv_file
		update_value ZONE		trusted			$if_priv_file
		LN

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

		line_separtor
		info "Configuration du dépôt"
		# TODO rendre configurable le nom du fichier !
		exec_cmd "cp -fp ~/plescripts/yum/public-yum-ol7.repo /etc/yum.repos.d/public-yum-ol7.repo"
		LN
		exec_cmd "echo \"$infra_hostname:$infra_olinux_repository_path /mnt$infra_olinux_repository_path nfs ro,$nfs_options,comment=systemd.automount 0 0\" >> /etc/fstab"
		exec_cmd mount /mnt$infra_olinux_repository_path
		LN

		line_separator
		exec_cmd yum -y install nfs-utils iscsi-initiator-utils deltarpm chrony wget net-tools vim-enhanced unzip tmux deltarpm

		case $type_shared_fs in
			nfs)
				line_separator
				exec_cmd "echo \"$client_hostname:/home/$common_user_name/plescripts /root/plescripts nfs rw,$nfs_options,comment=systemd.automount"
				exec_cmd -c mount -a /mnt/plescripts
				LN
			;;

			vbox)
				line_separator
				exec_cmd "echo \"plescripts /mnt/plescripts vboxsf defaults,uid=kangs,gid=users,_netdev 0 0\" >> /etc/fstab"
				exec_cmd -c mount -a /mnt/plescripts
				LN
			;;
		esac
		;;

	infra)
		line_separator
		info "Update OS"
		test_if_rpm_update_available
		[ $? -eq 0 ] && exec_cmd yum -y update || true
		LN

		line_separator
		exec_cmd yum -y install nfs-utils git targetcli deltarpm chrony wget net-tools vim-enhanced unzip tmux deltarpm createrepo
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

		exec_cmd "firewall-cmd --add-service=nfs --permanent --zone=trusted"
		exec_cmd "firewall-cmd --reload"
		LN

		line_separator
		case $type_shared_fs in
			nfs)
				exec_cmd "echo \"$client_hostname:/home/$common_user_name/plescripts /root/plescripts nfs rw,$nfs_options,async,comment=systemd.automount"
				LN
				;;

			vbox)
				exec_cmd "echo \"plescripts  /mnt/plescripts     vboxsf defaults,uid=kangs,gid=users,_netdev 0 0\" >> /etc/fstab"
				LN
				;;
		esac

		line_separator
		exec_cmd "~/plescripts/san/create_vg.sh -device=sdb -vg=asm01"
		LN

		line_separator
		info "Configure SAN"
		exec_cmd "~/plescripts/san/targetcli_default_cfg.sh"
		LN

		line_separator
		info "Clonage du dépôt Oracle Linux"
		exec_cmd "~/plescripts/yum/sync_oracle_repository.sh -copy_iso"
		;;
esac

exec_cmd ~/plescripts/ntp/config_ntp.sh -role=$role

exec_cmd ~/plescripts/gadgets/install.sh $role

line_separator
exec_cmd "~/plescripts/shell/set_plymouth_them"
LN

