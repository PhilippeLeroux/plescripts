#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage="Usage : $ME -db=<id> -node=<No>"

typeset		db=undef
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

exit_if_file_not_exist $node_file "-db or -node invalid."

line_separator
IFS=':' read db_type server_name ip_pub vip_name vip_ip ip_iscsi_name ip_iscsi db_name instance_name<<<"$(cat $node_file)"
info "Configure node $p_i_node"
info "	server     : $server_name / $ip_pub"
if [ $db_type == rac ]
then
	info "	vip        : $vip_name / $vip_ip"
	info "	ip rac     : ${server_name}-rac / ${if_rac_network}.${ip_iscsi##*.}"
fi
info "	ip iscsi   : ${server_name}-iscsi / $ip_iscsi"
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
update_value BOOTPROTO	static				$if_iscsi_file
update_value IPADDR		$ip_iscsi			$if_iscsi_file
update_value USERCTL	yes					$if_iscsi_file
update_value ONBOOT		yes 				$if_iscsi_file
update_value PREFIX		$if_iscsi_prefix	$if_iscsi_file
update_value MTU		9000				$if_iscsi_file
remove_value NETMASK						$if_iscsi_file
if_hwaddr=$(get_if_hwaddr $if_iscsi_name)
update_value HWADDR		$if_hwaddr			$if_iscsi_file
update_value ZONE		trusted				$if_iscsi_file
# Effectue la commande 2 fois car la première insère et ne met pas de double quotes
# le seconde update met les double quotes ????
update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_iscsi_file
update_value ETHTOOL_OPTS "\"speed 1000 duplex full autoneg off\"" $if_iscsi_file
LN

if [[ $db_type == rac* ]]
then
	line_separator
	#>	HACK
	#	Le n° du nœud IP est identique sur les réseaux iscsi et RAC, le fichier de
	#	configuration ne contient pas l'information sur le réseau RAC mais il peut
	#	être facilement déduit :
	#		- global.cfg est inclus maintenant (depuis presque le début je crois)
	#		- je lie le n° du nœud IP ISCSI
	#	et je l'adresse IP de l'interco RAC.
	#<	HACK
	#	TODO : je crois qu'il va falloir que je m'occupe sérieusement de ces fichiers
	#	de configurations que ne servent pas à grand chose aujourd'hui et rendent
	#	difficile la compréhension du code.
	typeset -r ip_rac=${if_rac_network}.${ip_iscsi##*.}
	info "Configure interface $if_rac_name :"
	if [ ! -f $if_rac_file ]
	then	# Je pense que le fichier n'existera pas (création tardive de la NIC) donc
			# par précotion je fais ce test et je copie if_iscsi_file si besoin.
		exec_cmd "cp $if_iscsi_file $if_rac_file"
		update_value NAME	$if_rac_name	$if_rac_file
		update_value DEVICE	$if_rac_name	$if_rac_file
	fi

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
exec_cmd "echo \"$ip_pub	$server_name\" >> /etc/hosts"
if [[ $db_type == rac* ]]
then
	exec_cmd "echo \"$vip_ip	$vip_name\" >> /etc/hosts"
	exec_cmd "echo \"#$ip_rac	${server_name}-rac\" >> /etc/hosts"
fi
exec_cmd "echo \"#$ip_iscsi	${server_name}-iscsi\" >> /etc/hosts"

if [[ $db_type == rac* ]]
then	# Inscrit dans /etc/hosts les informations concernant les autres nœuds.
	exec_cmd "echo \"\" >> /etc/hosts"
	exec_cmd "echo \"#Other nodes :\" >> /etc/hosts"
	for nf in $cfg_path/node*
	do
		if [ "$nf" != "$node_file" ]
		then
			IFS=':' read f1 server_nameo ip_pubo vip_nameo vip_ipo ip_iscsi_nameo ip_iscsio rem<<<"$(cat $nf)"
			exec_cmd "echo \"$ip_pubo	$server_nameo\" >> /etc/hosts"
			exec_cmd "echo \"$vip_ipo	$vip_nameo\" >> /etc/hosts"
			typeset ip_raco=${if_rac_network}.${ip_iscsio##*.}
			exec_cmd "echo \"#$ip_raco	${server_nameo}-rac\" >> /etc/hosts"
			exec_cmd "echo \"#$ip_iscsio	${server_nameo}-iscsi\" >> /etc/hosts"
		fi
	done
fi
LN

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
