#!/bin/bash

#	ts=4 sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

. ~/plescripts/global.cfg

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=<str> [-count_nodes=<#>]
	-count_nodes est obligatoire si les fichiers de configurations n'existent plus.

	1) supprime tous les initiators correspondant à la base.
	2) supprime le backstore.
	3) supprime les LVs du VG asm01."

typeset db=undef
typeset -i count_nodes=-1

while [ $# -ne 0 ]
do
	case $1 in
		-db=*)
			db=${1##*=}
			shift
			;;

		-count_nodes=*)
			count_nodes=${1##*=}
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

if [ $count_nodes -eq -1 ]
then
	typeset -r cfg_path=~/plescripts/database_servers/$db
	if [ ! -d $cfg_path ] 
	then
		error "$db config files not exists !"
		LN
		info "$str_usage"
		exit 1
	fi

	count_nodes=$(ls -1 $cfg_path/node* | wc -l)
fi

for node in $( seq 1 $count_nodes )
do
	initiator_name=$(get_initiator_for $db $node)
	~/plescripts/san/delete_initiator.sh -name=$initiator_name
	#	Le nom du bookmark est le nom du serveur.
	bookmark_name=$(echo $initiator_name | sed "s/.*\(srv.*\):\(.*\)/\1\2/")
	exec_cmd -c targetcli bookmarks del $bookmark_name
done
LN

exec_cmd -c ~/plescripts/san/delete_backstore.sh -vg_name=asm01 -prefix=$db -all
LN

exec_cmd -c ~/plescripts/san/remove_lv.sh -vg_name=asm01 -prefix=$db -all
LN

exec_cmd "~/plescripts/san/save_targetcli_config.sh -name=\"reset_all_$db\""


