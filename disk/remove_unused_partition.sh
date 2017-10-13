#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

La partition est supprimée puis le disque est vidé.
"

must_be_user root

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

while read partition
do
	type="$(disk_type $partition)"
	[ $type != unused ] && continue || true

	typeset	disk=${partition:0:${#partition}-1}
	info "partition $partition unused :"
	delete_partition $disk
	clear_device $disk
	LN
done<<<"$(find /dev -regex "/dev/sd.*1" | sort)"
