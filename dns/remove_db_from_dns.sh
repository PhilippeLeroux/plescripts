#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

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
			db=${1##*=}
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

typeset -r cfg_path=~/plescripts/database_servers/$db
exit_if_dir_not_exists $cfg_path

typeset -ri count_nodes=$(ls -1 $cfg_path/node* | wc -l)

for node_file in $cfg_path/node*
do
	server_name=$(cat $node_file | cut -d: -f2)
	exec_cmd ~/plescripts/dns/remove_server.sh -name=$server_name -no_restart
	[ $count_nodes -gt 1 ] && exec_cmd ~/plescripts/dns/remove_server.sh -name=$server_name-vip -no_restart
	LN
done

if [ -f $cfg_path/scanvips ]
then
	scan_name=$(cat $cfg_path/scanvips | cut -d: -f1)
	exec_cmd ~/plescripts/dns/remove_server.sh -name=$scan_name -no_restart
	LN
fi

exec_cmd "systemctl restart named.service"
LN
