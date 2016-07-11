#!/bin/ksh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=<id> -node=<No>"

typeset	db=undef
typeset	node=undef

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
			;;
	esac
done

exit_if_param_undef db		$str_usage
exit_if_param_undef node	$str_usage

typeset -r	cfg_path=~/plescripts/database_servers/$db
typeset -r	node_file=$cfg_path/node$node
typeset -r	scanvips_file=$cfg_path/scanvips

exit_if_file_not_exists $node_file "$str_usage"

line_separator
info "DNS : ajout du serveur et de sa vip"
IFS=':' read db_type server_name ip_pub vip_name vip_ip ip_priv_name ip_priv db_name instance_name<<<"$(cat $node_file)"
exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh $first_arg -name=$server_name -ip=$ip_pub\""
[[ $db_type == rac* ]] && exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh $first_arg -name=$vip_name -ip=$vip_ip\""
LN

if [ -f $scanvips_file ]
then
	line_separator
	info "DNS : ajout des scan vips."
	IFS=':' read scan_name vip1 vip2 vip3<<<"$(cat $scanvips_file)"
	exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh $first_arg -name=$scan_name -ip=$vip1\""
	exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh $first_arg -name=$scan_name -ip=$vip2\""
	exec_cmd "ssh -t $dns_conn \"cd plescripts/dns && ./add_server_2_dns.sh $first_arg -name=$scan_name -ip=$vip3\""
	LN
fi

