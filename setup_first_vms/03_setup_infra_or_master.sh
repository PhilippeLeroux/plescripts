#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -role=infra|master"

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
		ip_pub=${infra_ip}
		ip_priv=${if_priv_network}.${infra_ip_node}
		if [ "$(hostname -s)" != "$infra_hostname" ]
		then
			error "Le nom du serveur ne correspond pas à infra_hostname=$infra_hostname"
			error "du fichier ~/plescripts/global.cfg"
			exit 1
		fi

		if [ "$(hostname -d)" != "$infra_domain" ]
		then
			error "Le domaine du serveur ne correspond pas à infra_domain"
			error "du fichier ~/plescripts/global.cfg"
			exit 1
		fi

		if [ "$ip_pub" != "$infra_ip" ]
		then
			error "L'ip du serveur ne correspond pas à infra_ip"
			error "du fichier ~/plescripts/global.cfg"
			exit 1
		fi

		exec_cmd "cp ~/plescripts/myconfig/bashrc_extensions ~/.bashrc_extensions"
		cat << EOS >> ~/.bashrc
[ -f ~/.bashrc_extensions ] && . ~/.bashrc_extensions || true
~/plescripts/update_perms.sh >/dev/null 2>&1
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
		;;

	master)
		ip_pub=${infra_network}.${master_ip_node}
		ip_priv=${if_priv_network}.$master_ip_node
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

info "Create user $common_user_name"
exec_cmd "useradd -g users -M -N -u 1000 $common_user_name"
LN

typeset -i count_error=0

if [ $role == infra ]
then
	info "Configure interface $if_net_name :"
	if [ ! -f $if_net_file ]
	then
		error "L'interface $if_net_name n'existe pas !"
		count_error=count_error+1
	else
		update_value ONBOOT		yes				$if_net_file
		update_value USERCTL	no				$if_net_file
		remove_value HWADDR						$if_net_file
		remove_value UUID						$if_net_file
		update_value PEERDNS	no				$if_net_file
		update_value DNS1		$dns_ip			$if_net_file
		update_value DNS2		"192.168.1.1"	$if_net_file
		update_value ZONE		public			$if_net_file
		LN
	fi
else
	update_value BOOTPROTO	none	$if_net_file
fi

info "Configure interface $if_pub_name :"
if [ ! -f $if_pub_file ]
then
	error "L'interface $if_pub_name n'existe pas !"
	count_error=count_error+1
else
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
	update_value GATEWAY	$dns_ip			$if_pub_file
	LN
fi

info "Configure interface $if_priv_name :"
if [ ! -f $if_priv_file ]
then
	error "L'interface $if_priv_name n'existe pas !"
	count_error=count_error+1
else
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
fi

case $role in
	master)
		line_separator
		info "Disable selinux"
		update_value SELINUX disabled /etc/selinux/config
		LN

		line_separator
		exec_cmd yum -y install nfs-utils iscsi-initiator-utils deltarpm

		line_separator
		exec_cmd "echo \"$infra_hostname:/root/plescripts /mnt/plescripts nfs rsize=8192,wsize=8192,timeo=14,intr\" >> /etc/fstab"
		exec_cmd -c mkdir /mnt/plescripts
		exec_cmd -c mount /mnt/plescripts
		LN
		;;

	infra)
		line_separator
		exec_cmd "~/plescripts/update_perms.sh"
		LN

		line_separator
		exec_cmd yum -y install nfs-utils git targetcli deltarpm
		LN

		line_separator
		exec_cmd "cp ~/plescripts/san/pletarget.service /usr/lib/systemd/system/"
		exec_cmd systemctl enable pletarget
		exec_cmd systemctl start pletarget
		LN

		exec_cmd systemctl enable rpcbind
		exec_cmd systemctl start rpcbind
		LN

		exec_cmd systemctl enable nfs-server
		exec_cmd systemctl start nfs-server
		LN

		line_separator
		exec_cmd "sysctl -w net.ipv4.ip_forward=1"
		exec_cmd "echo \"net.ipv4.ip_forward = 1\" >> /etc/sysctl.d/ip_forward.conf"
		exec_cmd "firewall-cmd --permanent --direct --passthrough ipv4 -t nat -I POSTROUTING -o $if_net_name -j MASQUERADE -s ${infra_network}.0/24"
		exec_cmd "firewall-cmd --reload"
		LN

		line_separator
		info "Export /root/plescripts & /root/oracle_install :"
		exec_cmd "echo \"/root/plescripts *(rw,sync,no_root_squash,no_subtree_check)\" >> /etc/exports"
		exec_cmd "mkdir /root/oracle_install"
		exec_cmd "echo \"/root/oracle_install *(rw,sync,no_root_squash,no_subtree_check)\" >> /etc/exports"
		exec_cmd exportfs -a
		LN

		exec_cmd "~/plescripts/san/create_vg.sh -device=sdb -vg=asm01"
		;;
esac

exec_cmd ~/plescripts/ntp/config_ntp.sh -role=$role

exec_cmd ~/plescripts/gadgets/install.sh $role

if [ $role == master ]
then
	exec_cmd rm -rf ~/plescripts
	exec_cmd ln -s /mnt/plescripts ~/plescripts
fi
