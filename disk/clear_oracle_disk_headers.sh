#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
EXEC_CMD_ACTION=NOP

typeset -r str_usage=\
"Usage $0 [-doit]
Without -doit only show cmds.

Clear all oracle disk headers."

while [ $# -ne 0 ]
do
	case $1 in
		-doit)
			EXEC_CMD_ACTION=EXEC
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
			LN

		    exit 1
			;;
	esac
done

script_start

oracleasm listdisks |\
while read oracle_disk_name
do
	part_name=$(get_os_disk_used_by_oracleasm $oracle_disk_name)
	disk_name=$(echo $part_name | sed "s/^\(.*\)[0-9]\{1,\}$/\1/")

	info "clear $oracle_disk_name :"
	clear_device $part_name
	LN
done

exec_cmd oracleasm scandisks
LN

exec_cmd oracleasm listdisks
LN

script_stop "Script time :"

[ $EXEC_CMD_ACTION = NOP ] && info "$str_usage"

exit 0
