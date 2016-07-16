#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
"

[ $USER != root ] && error "Only root can execute this script" && exit 1

typeset	drop_partition=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

get_iscsi_disks |\
while read disk idisk
do
	type="$(disk_type $disk)"
	if [ "$type" = "dos" ]
	then
		typeset -i nb_part=$(count_partition_for $disk)
		if [ $nb_part -ne 1 ]
		then
			warning "Pas d'action sur $disk car $nb_part partition(s)."
			continue
		fi

		part_name=${disk}1
		part_type="$(disk_type $part_name)"

		[ "$part_type" != "unused" ] && continue

		delete_partition $disk
		LN
	fi
done
