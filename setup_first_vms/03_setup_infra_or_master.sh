#!/bin/sh
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
		echo -e "\${RED}\$count_lv_error lvs errors : reboot me !\${NORM}"
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

		line_separator
		exec_cmd yum -y install nfs-utils iscsi-initiator-utils deltarpm chrony wget net-tools vim-enhanced unzip tmux

		case $type_shared_fs in
			nfs)
				line_separator
				exec_cmd "echo \"$client_hostname:/home/$common_user_name/plescripts /mnt/plescripts nfs rsize=8192,wsize=8192,timeo=14,intr,comment=systemd.automount\" >> /etc/fstab"
				exec_cmd -c mount -a /mnt/plescripts
				LN
			;;

			vbox)
				line_separator
				exec_cmd "echo \"sf_plescripts /mnt/plescripts vboxsf defaults,uid=kangs,gid=users,_netdev 0 0\" >> /etc/fstab"
				exec_cmd -c mount -a /mnt/plescripts
				LN
			;;
		esac

		line_separator
		exec_cmd "~/plescripts/shell/set_plymouth_them"
		LN

		;;

	infra)
		line_separator
		info "Update OS"
		exec_cmd yum -y update
		LN

		line_separator
		exec_cmd yum -y install nfs-utils git targetcli deltarpm chrony wget net-tools vim-enhanced unzip tmux
		LN

		line_separator
		exec_cmd "sysctl -w net.ipv4.ip_forward=1"
		exec_cmd "echo \"net.ipv4.ip_forward = 1\" >> /etc/sysctl.d/ip_forward.conf"
		exec_cmd "firewall-cmd --permanent --direct --passthrough ipv4 -t nat -I POSTROUTING -o $if_net_name -j MASQUERADE -s ${infra_network}.0/24"
		exec_cmd "firewall-cmd --reload"
		LN

		line_separator
		exec_cmd "echo \"$client_hostname:/home/$common_user_name/plescripts /root/plescripts nfs rsize=8192,wsize=8192,timeo=14,intr,comment=systemd.automount\" >> /etc/fstab"
		LN

		line_separator
		exec_cmd "echo \"/root/$oracle_install ${infra_network}.0/${infra_mask}(rw,sync,no_root_squash,no_subtree_check)\" >> /etc/exports"
		LN

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
		exec_cmd "~/plescripts/san/create_vg.sh -device=sdb -vg=asm01"
		LN

		line_separator
		info "Configure SAN"
		run_ssh "~/plescripts/san/targetcli_default_cfg.sh"
		LN

		line_separator
		info "Install workaround for target :"
		exec_cmd "cp ~/plescripts/san/pletarget.service /usr/lib/systemd/system/"
		exec_cmd systemctl enable pletarget
		LN

		line_separator
		exec_cmd "~/plescripts/shell/set_plymouth_them"
		LN
		;;
esac

exec_cmd ~/plescripts/ntp/config_ntp.sh -role=$role

exec_cmd ~/plescripts/gadgets/install.sh $role
