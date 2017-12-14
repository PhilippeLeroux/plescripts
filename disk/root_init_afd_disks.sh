#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/disklib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

Ne doit être utilisé que lors de l'installation du grid.
"

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

exit_if_param_undef db	"$str_usage"

must_be_user root

cfg_exists $db

typeset -ri max_nodes=$(cfg_max_nodes $db)

cfg_load_node_info $db 1

typeset -a other_node_list
if [ $cfg_db_type == rac ]
then
	for (( i=2; i <= max_nodes; ++i ))
	do
		cfg_load_node_info $db $i
		other_node_list+=( $cfg_server_name )
	done
fi

fake_exec_cmd export ORACLE_HOME=$GRID_HOME
export ORACLE_HOME=$GRID_HOME
fake_exec_cmd export ORACLE_BASE=/tmp
export ORACLE_BASE=/tmp
LN

typeset -i nr_disk=1

while read device
do
	if [ x"$device" == x ]
	then
		warning "No device found."
		LN
		exit 0
	fi

	oracle_label=$(printf "s1disk${db}%02d" $nr_disk)
	((++nr_disk))
	# Pour un standalone il n'est pas nécessaire de changer les droits, mais
	# pour un RAC il faut absolument le faire.
	for onode in ${other_node_list[*]}
	do
		exec_cmd "ssh $onode 'chown grid:asmadmin $device'"</dev/null
	done
	exec_cmd chown grid:asmadmin $device
	exec_cmd $ORACLE_HOME/bin/asmcmd afd_label $oracle_label $device --init
	LN
done<<<"$(get_unused_disks_without_partitions)"
