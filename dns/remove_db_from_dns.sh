#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage="Usage : $ME -db=<>"

typeset -r DOMAIN_NAME=$(hostname -d)

typeset -r named_file=/var/named/named.${DOMAIN_NAME}
typeset -r reverse_file=/var/named/reverse.${DOMAIN_NAME}

exit_if_file_not_exists $named_file
exit_if_file_not_exists $reverse_file

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info $str_usage
			exit 1
			;;
	esac
done

exit_if_param_undef db	$str_usage

cfg_exists $db

typeset -ri max_nodes=$(cfg_max_nodes $db)

info "Backup DNS configuration :"
exec_cmd cp $named_file ${named_file}.backup
exec_cmd cp $reverse_file ${reverse_file}.backup
LN

for (( inode=1; inode <= max_nodes; ++inode ))
do
	cfg_load_node_info $db $inode
	exec_cmd ~/plescripts/dns/remove_server.sh -name=$cfg_server_name -no_restart
	[ $max_nodes -gt 1 ] && exec_cmd ~/plescripts/dns/remove_server.sh -name=$cfg_server_name-vip -no_restart
	LN
done

if [ -f $cfg_path_prefix/$db/scanvips ]
then
	scan_name=$(cat $cfg_path_prefix/$db/scanvips | cut -d: -f1)
	exec_cmd ~/plescripts/dns/remove_server.sh -name=$scan_name -no_restart
	LN
fi

exec_cmd "systemctl restart named.service"
LN
