#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset		db=undef
typeset	-i	count_nodes=-1
typeset		vg_name=$infra_vg_name_for_db_luns

typeset -r str_usage=\
"Usage : $ME
	-db=<str>
	[-count_nodes=<#>]
	[-vg_name=$vg_name]

	-count_nodes est obligatoire si les fichiers de configurations n'existent plus.

	1) supprime tous les initiators correspondant à la base.
	2) supprime le backstore.
	3) supprime les LVs du VG $vg_name."


while [ $# -ne 0 ]
do
	case $1 in
		-db=*)
			db=${1##*=}
			shift
			;;

		-vg_name=*)
			vg_name=${1##*=}
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
	cfg_exists $db use_return_code
	if [ $? -ne 0 ]
	then
		error "Configuration file not exists, use -count_nodes"
		LN
		info "$str_usage"
		exit 1
	fi

	count_nodes=$(cfg_max_nodes $db)
fi

for node in $( seq $count_nodes )
do
	initiator_name=$(get_initiator_for $db $node)
	~/plescripts/san/delete_initiator.sh -name=$initiator_name
	#	Le nom du bookmark est le nom du serveur.
	bookmark_name=$(echo $initiator_name | sed "s/.*\(srv.*\):\(.*\)/\1\2/")
	exec_cmd -c targetcli bookmarks del $bookmark_name
done
LN

exec_cmd -c ~/plescripts/san/delete_backstore.sh -vg_name=$vg_name -prefix=$db -all
LN

exec_cmd -c ~/plescripts/san/remove_lv.sh -vg_name=$vg_name -prefix=$db -all
LN

exec_cmd "~/plescripts/san/save_targetcli_config.sh -name=\"reset_all_$db\""
LN
