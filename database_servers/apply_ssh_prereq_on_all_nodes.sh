#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage="Usage : $ME -db=<str>"

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

cfg_exists $db

typeset -ri max_nodes=$(cfg_max_nodes $db)

if [ $max_nodes -ne 2 ]
then
	error "NE FONCTIONNE PAS AVEC PLUS DE 2 NŒUDS !"
	exit 1
fi

typeset -a node_list

#	Charge le nom de tous les nœuds.
for inode in $( seq $max_nodes )
do
	cfg_load_node_info $db $inode
	node_list+=( $cfg_server_name )
done

exec_cmd "~/plescripts/ssh/setup_rac_ssh_equivalence.sh -server1=${node_list[0]} -server2=${node_list[1]}"
LN
