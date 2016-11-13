#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
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

cfg_exist $db

typeset -ri max_nodes=$(cfg_max_nodes $db)

if [ $max_nodes -eq 1 ]
then
	info "Single serveur."
else
	info "RAC cluster $count_nodes nodes."
fi

for inode in $( seq $max_nodes )
do
	cfg_load_node_info $db $inode
	exec_cmd "targetcli ls @$cfg_server_name"
	LN
done

exec_cmd targetcli sessions | grep ${db}
if [ $? -eq 0 ]
then
	info "Connected !"
else
	info "Not connected !"
fi
LN
