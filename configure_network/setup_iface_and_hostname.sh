#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage="Usage : $ME -db=<id> -node=<#>"

typeset		db=undef
typeset -i  node=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-node=*)
			node=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN

			info $str_usage
			LN
			exit 1
			;;
	esac
done

exit_if_param_undef db		$str_usage
exit_if_param_undef node	$str_usage

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

line_separator
cfg_load_node_info $db $node
info "Configure node $node"
info "	server     : $cfg_server_name / $cfg_server_ip"
if [ $cfg_db_type == rac ]
then
	info "	vip        : ${cfg_server_name}-vip / $cfg_server_vip"
	info "	ip rac     : ${cfg_server_name}-rac / ${if_rac_network}.${cfg_iscsi_ip##*.}"
fi
info "	ip iscsi   : ${cfg_server_name}-iscsi / $cfg_iscsi_ip"
LN

line_separator
info "Update /etc/hostname"
exec_cmd "echo \"$cfg_server_name.${infra_domain}\" > /etc/hostname"
LN

line_separator
info "Update Iface $if_pub_name :"
if_hwaddr=$(get_if_hwaddr $if_pub_name)
exec_cmd nmcli connection modify		$if_pub_name					\
				ipv4.method				manual							\
				ipv4.addresses			$cfg_server_ip/$if_pub_prefix	\
				ipv4.dns				$dns_ip							\
				connection.zone			trusted							\
				ethernet.mac-address	$if_hwaddr						\
				connection.autoconnect	yes
LN
update_variable UUID	$(uuidgen $if_pub_name)	$if_pub_file

line_separator
info "Update Iface $if_iscsi_name :"
if_hwaddr=$(get_if_hwaddr $if_iscsi_name)
exec_cmd nmcli connection modify		$if_iscsi_name					\
				ipv4.method				manual							\
				ipv4.addresses			$cfg_iscsi_ip/$if_iscsi_prefix	\
				ethernet.mtu			9000							\
				connection.zone			trusted							\
				ethernet.mac-address	$if_hwaddr						\
				connection.autoconnect	yes
LN
update_variable UUID	$(uuidgen $if_iscsi_name)	$if_iscsi_file

if [ $cfg_db_type == rac ]
then
	line_separator
	# Pour l'IP RAC lecture du dernier n° de l'IP iSCSI.
	typeset -r ip_rac=${if_rac_network}.${cfg_iscsi_ip##*.}
	info "Update Iface $if_rac_name :"
	exec_cmd nmcli connection add	con-name	$if_rac_name		\
									ifname		$if_rac_name		\
									type		ethernet
	LN

	if_hwaddr=$(get_if_hwaddr $if_rac_name)
	exec_cmd nmcli connection modify		$if_rac_name			\
					ipv4.method				manual					\
					ipv4.addresses			$ip_rac/$if_rac_prefix	\
					ethernet.mtu			9000					\
					connection.zone			trusted					\
					ethernet.mac-address	$if_hwaddr				\
					connection.autoconnect	yes
	LN
	update_variable UUID	$(uuidgen $if_rac_name)	$if_rac_file
fi

line_separator
info "Update /etc/hosts"
exec_cmd "echo \"\" >> /etc/hosts"
exec_cmd "echo \"#This node.\" >> /etc/hosts"
exec_cmd "echo \"$cfg_server_ip	$cfg_server_name\" >> /etc/hosts"
if [ $cfg_db_type == rac ]
then
	exec_cmd "echo \"$cfg_server_vip	${cfg_server_name}-vip\" >> /etc/hosts"
	exec_cmd "echo \"#$ip_rac	${cfg_server_name}-rac\" >> /etc/hosts"
fi
exec_cmd "echo \"#$cfg_iscsi_ip	${cfg_server_name}-iscsi\" >> /etc/hosts"

if [ $cfg_db_type == rac ]
then	# Inscrit dans /etc/hosts les informations concernant les autres nœuds.
	exec_cmd "echo \"\" >> /etc/hosts"
	exec_cmd "echo \"#Other nodes :\" >> /etc/hosts"
	typeset -i inode
	for inode in $( seq $max_nodes )
	do
		[ $inode -eq $node ] && continue || true
		cfg_load_node_info $db $inode
		exec_cmd "echo \"$cfg_server_ip	$cfg_server_name\" >> /etc/hosts"
		exec_cmd "echo \"$cfg_server_vip	${cfg_server_name}-vip\" >> /etc/hosts"
		typeset ip_raco=${if_rac_network}.${cfg_iscsi_ip##*.}
		exec_cmd "echo \"#$ip_raco	${cfg_server_name}-rac\" >> /etc/hosts"
		exec_cmd "echo \"#$cfg_iscsi_ip	${cfg_server_name}-iscsi\" >> /etc/hosts"
	done
fi
LN

typeset -r	scanvips_file=$cfg_path_prefix/$db/scanvips
if [ -f $scanvips_file ]
then
	line_separator
	IFS=':' read scan_name scan_vip1 scan_vip2 scan_vip3 <<<"$(cat $scanvips_file)"
	info "Update scan /etc/hosts"
	exec_cmd "echo \"\" >> /etc/hosts"
	exec_cmd "echo \"#Scan Adress\" >> /etc/hosts"
	exec_cmd "echo \"#$scan_name $scan_vip1\" >> /etc/hosts"
	exec_cmd "echo \"#$scan_name $scan_vip2\" >> /etc/hosts"
	exec_cmd "echo \"#$scan_name $scan_vip3\" >> /etc/hosts"
	LN
fi
