#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/san/targetclilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0

typeset 	db=undef
typeset	-i	lun=-1
typeset -i	count=1
typeset		vg_name=$infra_vg_name_for_db_luns

add_usage "-db='db id'"			"Identifiant de la base."
add_usage "-lun=#"				"N° de la première LUN."
add_usage "[-count=$count]"		"Nombre de LUN a supprimer."
add_usage "[-vg_name=$vg_name]"	"Nom du VG contenant les LUNs."

typeset	-r	str_usage=\
"Usage :
$ME
$(print_usage)
"

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

cfg_exists $db

set_working_vg $vg_name

# $1 node number
# $2 LUN number
function remove_lun_for_server
{
	typeset -r	node=$(printf "%02d" $1)
	typeset -ri	nr_lun=$2

	typeset	-r	acls_path=/iscsi/$iscsi_initiator_prefix$db:$node/tpg1/acls/$iscsi_initiator_prefix$db:$node
	typeset -r	luns_path=/iscsi/$iscsi_initiator_prefix$db:$node/tpg1/luns

	info "delete lun $nr_lun."
	exec_cmd "$(printf "targetcli %s delete %02d" $acls_path $nr_lun)"
	exec_cmd "$(printf "targetcli %s delete %02d" $luns_path $nr_lun)"
	LN
}

typeset -ri	max_nodes=$(cfg_max_nodes $db)

line_separator
info "Delete $count LUNs start to LUN $lun"
LN

for (( inode=1; inode<=max_nodes; ++inode ))
do
	line_separator
	info "Delete LUN for node $inode"
	LN

	for (( i = 0; i < count; ++i ))
	do
		remove_lun_for_server $inode $((lun+i))
	done
done

line_separator
info "Delete $count disks from backstore"
for (( i = 0; i < count; ++i ))
do
	disk_name=$(get_disk_name $((lun+i)) $db)
	exec_cmd targetcli /backstores/block delete $disk_name
done
LN

exec_cmd "~/plescripts/san/save_targetcli_config.sh -name=delete_db_luns"
LN

exec_cmd "~/plescripts/san/remove_lv.sh -vg_name=$vg_name -prefix=$db -first_no=$lun -count=$count"
LN
