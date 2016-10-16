#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=<str>
	-lun=<#>
	[-count=<#>]   Par défaut vaut 1
	-vg_name=<str>
"

script_banner $ME $*

typeset 	db=undef
typeset	-i	lun=-1
typeset		vg_name=undef

typeset -i	count=1

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

		-lun=*)
			lun=10#${1##*=}
			shift
			;;

		-count=*)
			count=${1##*=}
			shift
			;;

		-vg_name=*)
			vg_name=${1##*=}
			shift
			;;


		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef db		"$str_usage"
exit_if_param_undef lun		"$str_usage"
exit_if_param_undef vg_name	"$str_usage"

typeset	-r	cfg_path=~/plescripts/database_servers/$db
exit_if_dir_not_exist "$cfg_path" "$str_usage"

typeset -ri	count_nodes=$(ls -1 $cfg_path/node* | wc -l)

function remove_lun_for_server
{
	typeset -r	node=$(printf "%02d" $1)
	typeset -ri	nr_lun=$2

	typeset	-r	acls_path=/iscsi/$iscsi_initiator_prefix$db:$node/tpg1/acls/$iscsi_initiator_prefix$db:$node
	typeset -r	luns_path=/iscsi/$iscsi_initiator_prefix$db:$node/tpg1/luns

	info "delete lun $nr_lun"
	exec_cmd "$(printf "targetcli %s delete %02d" $acls_path $nr_lun)"
	exec_cmd "$(printf "targetcli %s delete %02d" $luns_path $nr_lun)"
	LN
}

line_separator
info "Delete $count LUNs start to LUN $lun"
for inode in $( seq 1 $count_nodes )
do
	for ilun in $( seq $lun $(( lun + count - 1 )) )
	do
		remove_lun_for_server $inode ilun
	done
done

line_separator
info "Delete $count disks from backstore"
for ilun in $( seq $lun $(( lun + count - 1 )) )
do
	exec_cmd targetcli /backstores/block delete $(printf "%s_lv%s%02d" $vg_name ${db} $ilun)
done
LN

exec_cmd "~/plescripts/san/save_targetcli_config.sh -name=delete_db_luns"
LN

exec_cmd "~/plescripts/san/remove_lv.sh -vg_name=$vg_name -prefix=$db -first_no=$lun -count=$count"
LN
