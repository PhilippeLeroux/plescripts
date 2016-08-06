#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh

. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage="Usage : $ME -db=<id> -node=<No>"

typeset	 db=undef
typeset -i  node=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_arg=-emul
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

typeset -r  cfg_path=~/plescripts/database_servers/$db

typeset -r	node_file=$cfg_path/node$node
typeset -r	scanvips_file=$cfg_path/scanvips

exit_if_file_not_exists $node_file "-db or -node invalid."

line_separator
IFS=':' read db_type server_name ip_pub vip_name vip_ip ip_priv_name ip_priv db_name instance_name<<<"$(cat $node_file)"
info "Configure node $p_i_node"
info "	server     : $server_name / $ip_pub"
[ $db_type == rac ] && info "	vip        : $vip_name / $vip_ip"
info "	ip private : $ip_priv_name / $ip_priv"
LN

line_separator
info "Update /etc/hostname"
exec_cmd "echo \"$server_name.${infra_domain}\" > /etc/hostname"
LN

line_separator
info "Configure interface $if_pub_name :"
update_value BOOTPROTO	static			$if_pub_file
update_value IPADDR		$ip_pub 		$if_pub_file
update_value DNS1		$dns_ip			$if_pub_file
update_value USERCTL	yes				$if_pub_file
update_value ONBOOT		yes 			$if_pub_file
update_value PREFIX		24				$if_pub_file
remove_value NETMASK					$if_pub_file
if_hwaddr=$(get_if_hwaddr $if_pub_name)
update_value HWADDR		$if_hwaddr		$if_pub_file
update_value ZONE		trusted			$if_pub_file
LN

line_separator
info "Configure interface $if_priv_name :"
update_value BOOTPROTO	static			$if_priv_file
update_value IPADDR		$ip_priv		$if_priv_file
update_value USERCTL	yes				$if_priv_file
update_value ONBOOT		yes 			$if_priv_file
update_value PREFIX		24				$if_priv_file
update_value MTU		9000			$if_priv_file
remove_value NETMASK					$if_priv_file
if_hwaddr=$(get_if_hwaddr $if_priv_name)
update_value HWADDR		$if_hwaddr		$if_priv_file
update_value ZONE		trusted			$if_priv_file
# Effectue la commande 2 fois car la première insert et ne met pas de double quote
# alors que la seconde update et met les double quote.
update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_priv_file
update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_priv_file
LN

line_separator
info "Update /etc/hosts"
exec_cmd "echo \"$ip_pub	$server_name\" >> /etc/hosts"
[[ $db_type == rac* ]] && exec_cmd "echo \"$vip_ip	$vip_name\" >> /etc/hosts"
exec_cmd "echo \"#$ip_priv	$ip_priv_name\" >> /etc/hosts"

for nf in $cfg_path/node*
do
	if [ "$nf" != "$node_file" ]
	then
		IFS=':' read f1 server_nameo ip_pubo vip_nameo vip_ipo ip_priv_nameo ip_privo rem<<<"$(cat $nf)"
		exec_cmd "echo \"$ip_pubo	$server_nameo\" >> /etc/hosts"
		[[ $db_type == rac* ]] && exec_cmd "echo \"$vip_ipo	$vip_nameo\" >> /etc/hosts"
		exec_cmd "echo \"#$ip_privo	$ip_priv_nameo\" >> /etc/hosts"
	fi
done
LN

if [ -f $scanvips_file ]
then
	line_separator
	IFS=':' read scan_name scan_vip1 scan_vip2 scan_vip3 <<<"$(cat $scanvips_file)"
	info "Update scan /etc/hosts"
	exec_cmd "echo \"#$scan_name $scan_vip1\" >> /etc/hosts"
	exec_cmd "echo \"#$scan_name $scan_vip2\" >> /etc/hosts"
	exec_cmd "echo \"#$scan_name $scan_vip3\" >> /etc/hosts"
fi

exit 0
