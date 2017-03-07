#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
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

script_banner $ME $*

exit_if_param_undef db	"$str_usage"

typeset -r upper_db=$(to_upper $db)

fake_exec_cmd export ORACLE_HOME=$GRID_HOME
export ORACLE_HOME=$GRID_HOME
fake_exec_cmd export ORACLE_BASE=/tmp
export ORACLE_BASE=/tmp
LN

typeset -i nr_disk=1

while read device
do
	[ x"$device" == x ] && exit
	oracle_label=$(printf "s1disk${db}%02d" $nr_disk)
	((++nr_disk))
	exec_cmd $ORACLE_HOME/bin/asmcmd afd_label $oracle_label $device --init
	exec_cmd $ORACLE_HOME/bin/asmcmd afd_lslbl $device
	LN
done<<<"$(get_unused_disks_without_partitions)"
