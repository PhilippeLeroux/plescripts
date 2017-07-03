#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -count=# [-skip_disks=#]"

typeset -i count=-1
typeset -i skip_disks=0

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

		-skip_disks=*)
			skip_disks=${1##*=}
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

#ple_enable_log -params $PARAMS

must_be_user root

exit_if_param_undef count	"$str_usage"

typeset		list_disks
typeset	-i	nr_disk=0
typeset -i	nr_disk_skipped=0

while read device
do
	if [ x"$device" == x ]
	then
		error "$(hostname -s) : No disk unused."
		exit 1
	fi
	((++nr_disk))
	if [[ $skip_disks -ne 0 ]]
	then
		if [[ $nr_disk -le $skip_disks ]]
		then
			continue
		else
			nr_disk=1
			skip_disks=0
		fi
	fi
	[ x"$list_disks" == x ] && list_disks=$device || list_disks="${list_disks},$device"
	if [ $nr_disk -eq $count ]
	then
		echo "$list_disks"
		exit 0
	fi
done<<<"$(get_unused_disks_without_partitions)"

error "$(hostname -s) : Only #${nr_disk} available (requested #$count)"
exit 1
