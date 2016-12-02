#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

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

cfg_exist $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

line_separator
cfg_load_node_info $db $node
info "Configure node $node"
info "	server     : $cfg_server_name / $cfg_server_ip"
if [ $max_nodes -gt 1 ]
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
info "Configure interface $if_pub_name :"
update_value NAME		$if_pub_name	$if_pub_file
update_value DEVICE		$if_pub_name	$if_pub_file
update_value BOOTPROTO	static			$if_pub_file
update_value IPADDR		$cfg_server_ip 	$if_pub_file
update_value DNS1		$dns_ip			$if_pub_file
update_value USERCTL	yes				$if_pub_file
update_value ONBOOT		yes 			$if_pub_file
update_value PREFIX		$if_pub_prefix	$if_pub_file
remove_value NETMASK					$if_pub_file
if_hwaddr=$(get_if_hwaddr $if_pub_name)
update_value HWADDR		$if_hwaddr		$if_pub_file
update_value ZONE		trusted			$if_pub_file
#	Pas d'accès internet.
remove_value GATEWAY					$if_pub_file
LN

line_separator
info "Configure interface $if_iscsi_name :"
exec_cmd "cp $if_pub_file $if_iscsi_file"
update_value NAME		$if_iscsi_name		$if_iscsi_file
update_value DEVICE		$if_iscsi_name		$if_iscsi_file
update_value BOOTPROTO	static				$if_iscsi_file
update_value IPADDR		$cfg_iscsi_ip		$if_iscsi_file
update_value USERCTL	yes					$if_iscsi_file
update_value ONBOOT		yes 				$if_iscsi_file
update_value PREFIX		$if_iscsi_prefix	$if_iscsi_file
update_value MTU		9000				$if_iscsi_file
remove_value NETMASK						$if_iscsi_file
if_hwaddr=$(get_if_hwaddr $if_iscsi_name)
update_value HWADDR		$if_hwaddr			$if_iscsi_file
if_uuid=$(uuidgen $if_iscsi_name)
update_value UUID		$if_uuid			$if_iscsi_file
update_value ZONE		trusted				$if_iscsi_file
# Effectue la commande 2 fois car la première insère et ne met pas de double quotes
# le seconde update met les double quotes ????
update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_iscsi_file
update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_iscsi_file
LN

if [ $max_nodes -gt 1 ]
then
	line_separator
	# Pour l'IP RAC lecture du dernier n° de l'IP iSCSI.
	typeset -r ip_rac=${if_rac_network}.${cfg_iscsi_ip##*.}
	info "Configure interface $if_rac_name :"
	exec_cmd "cp $if_iscsi_file $if_rac_file"
	update_value NAME		$if_rac_name		$if_rac_file
	update_value DEVICE		$if_rac_name		$if_rac_file
	update_value BOOTPROTO	static				$if_rac_file
	update_value IPADDR		$ip_rac				$if_rac_file
	update_value USERCTL	yes					$if_rac_file
	update_value ONBOOT		yes 				$if_rac_file
	update_value PREFIX		$if_rac_prefix		$if_rac_file
	update_value MTU		9000				$if_rac_file
	remove_value NETMASK						$if_rac_file
	if_hwaddr=$(get_if_hwaddr $if_rac_name)
	update_value HWADDR		$if_hwaddr			$if_rac_file
	update_value ZONE		trusted				$if_rac_file
	if_uuid=$(uuidgen $if_rac_name)
	update_value UUID		$if_uuid			$if_rac_file
	# Effectue la commande 2 fois car la première insert et ne met pas de double quote
	# alors que la seconde update et met les double quote.
	update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_rac_file
	update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_rac_file
	LN
fi

line_separator
info "Update /etc/hosts"
exec_cmd "echo \"\" >> /etc/hosts"
exec_cmd "echo \"#This node.\" >> /etc/hosts"
exec_cmd "echo \"$cfg_server_ip	$cfg_server_name\" >> /etc/hosts"
if [ $max_nodes -gt 1 ]
then
	exec_cmd "echo \"$cfg_server_vip	${cfg_server_name}-vip\" >> /etc/hosts"
	exec_cmd "echo \"#$ip_rac	${cfg_server_name}-rac\" >> /etc/hosts"
fi
exec_cmd "echo \"#$cfg_iscsi_ip	${cfg_server_name}-iscsi\" >> /etc/hosts"

if [ $max_nodes -gt 1 ]
then	# Inscrit dans /etc/hosts les informations concernant les autres nœuds.
	exec_cmd "echo \"\" >> /etc/hosts"
	exec_cmd "echo \"#Other nodes :\" >> /etc/hosts"
	for inode in $( seq 2 $max_nodes )
	do
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
