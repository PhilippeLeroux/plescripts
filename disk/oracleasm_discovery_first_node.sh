#/bin/bash

#	ts=4 sw=4

#	Une fois que les disques sont disponibles exécuter
#	ce scripts sur un noeud du RAC
#
#	Pour les autres noeuds utiliser oracleasm_discovery_other_nodes.sh

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

info "$ME $@"
typeset -r str_usage=\
"Usage : $ME -type_disk=ASM|FS"

typeset	type_disk=undef

while [ $# -ne 0 ]
do
	case $1 in
		-type_disk=*)
			type_disk=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			rm -f $PLELIB_LOG_FILE
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			LN
			exit 1
			;;
	esac
done

exit_if_param_invalid type_disk "ASM FS" "$str_usage"

cd ~/plescripts/disk

exec_cmd "./discovery_target.sh"

exec_cmd "./create_partitions_on_new_disks.sh -clear_partitions"

line_separator
case $type_disk in
	ASM)
		exec_cmd "./create_oracle_disk_on_new_part.sh"
		;;

	FS)
		exec_cmd "./create_oracle_fs_on_new_disks.sh"
		;;
esac

exit 0
