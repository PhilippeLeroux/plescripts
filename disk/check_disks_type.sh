#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME"

[ $USER != root ] && error "Only root can execute this script" && exit 1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

get_iscsi_disks |\
while read disk idisk
do
	type="$(disk_type $disk)"
	info -n "disk $disk "
	if [ "$type" = "unused" ]
	then
		echo "non utilisé."
	else
		echo -n "type $type"
		typeset -i nb_part=$(count_partition_for $disk)
		if [ $nb_part -ne 0 ]
		then
			echo ", partitions :"
			for ipart in $( seq 1 $nb_part )
			do
				part_name=${disk}$ipart
				part_type="$(disk_type $part_name)"
				info "	-$part_name type $part_type"
			done
		else
			LN
		fi
	fi
	LN
done
