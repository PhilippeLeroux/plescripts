#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=<id> -node=<No>"

typeset		db=undef
typeset	-i	node=-1

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
			;;
	esac
done

exit_if_param_undef db		$str_usage
exit_if_param_undef node	$str_usage

cfg_exist $db

typeset -ri	max_nodes=$(cfg_max_nodes $db)

line_separator
cfg_load_node_info $db $node
info "DNS : ajout dès/la IP du serveur :"
exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh -name=$cfg_server_name -ip=$cfg_server_ip\""
[ $max_nodes -gt 1 ] && exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh -name=${cfg_server_name}-vip -ip=$cfg_server_vip\""
LN

typeset -r	scanvips_file=$cfg_path_prefix/$db/scanvips
if [ -f $scanvips_file ]
then
	line_separator
	info "DNS : ajout des scan vips."
	IFS=':' read scan_name vip1 vip2 vip3<<<"$(cat $scanvips_file)"
	exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh -name=$scan_name -ip=$vip1\""
	exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh -name=$scan_name -ip=$vip2\""
	exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh -name=$scan_name -ip=$vip3\""
	LN
fi
