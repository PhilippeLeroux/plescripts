#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -count=#"

typeset -i count=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-count=*)
			count=${1##*=}
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

#ple_enable_log

script_banner $ME $*

must_be_user root

exit_if_param_undef count	"$str_usage"

typeset		list_disks
typeset	-i	nr_disk=0

while read device
do
	if [ x"$device" == x ]
	then
		error "$(hostname -s) : No disk unused."
		exit 1
	fi
	[ x"$list_disks" == x ] && list_disks=$device || list_disks="${list_disks},$device"
	((++nr_disk))
	if [ $nr_disk -eq $count ]
	then
		echo "$list_disks"
		exit 0
	fi
done<<<"$(get_unused_disks_without_partitions)"

error "$(hostname -s) : Only #${nr_disk} available (requested #$count)"
exit 1
