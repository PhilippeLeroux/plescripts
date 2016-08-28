#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=<str>
	Permet de visualiser les LUNs associées à une base
	et de voir si le serveur correspondant est connectée."

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
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

exit_if_param_undef db	"$str_usage"

typeset -r cfg_path=~/plescripts/database_servers/$db
exit_if_dir_not_exists $cfg_path "-db=$db not exists !"

typeset -ri count_nodes=$(ls -1 $cfg_path/node* | wc -l)

if [ $count_nodes -eq 1 ]
then
	info "Single serveur."
else
	info "RAC cluster $count_nodes nodes."
fi

for node_file in $cfg_path/node*
do
	server_name=$(cut -d: -f2<$node_file)
	exec_cmd "targetcli ls @$server_name"
	LN
done

exec_cmd targetcli sessions | grep ${db}
if [ $? -eq 0 ]
then
	info "Connected !"
else
	info "Not connected !"
fi
