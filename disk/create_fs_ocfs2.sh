#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-mount_point=name
	-device=/dev/xxx
	-action=[create|add]
"

script_banner $ME $*

typeset	add_to_cluster=no

typeset	db=undef
typeset	mount_point=undef
typeset	device=undef
typeset	action=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-mount_point=*)
			mount_point=${1##*=}
			shift
			;;

		-device=*)
			device=${1##*=}
			shift
			;;

		-action=*)
			action=${1##*=}
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

exit_if_param_undef		db					"$str_usage"
exit_if_param_undef		mount_point			"$str_usage"
exit_if_param_undef		device				"$str_usage"
exit_if_param_invalid	action "create add"	"$str_usage"

if [ "$device" == check ]
then
	info "Search unused disk :"
	device=$(get_unused_disks_without_partitions | head -1)
	if [ x"$device" == x ]
	then
		error "No device found."
		exit 1
	fi
fi

exec_cmd mkdir $mount_point
LN

#	BUG doc Oracle il faut créer le FS avant d'ajouter le device dans le cluster.
if [ $action == create ]
then
	exec_cmd mkfs.ocfs2 -L "ocfs2_${mount_point##*/}" $device
	LN
fi

exec_cmd o2cb add-heartbeat $db $device
LN

#	Util pour le premier disque :
exec_cmd -c /sbin/o2cb.init enable
LN

exec_cmd "echo \"$device  $mount_point  ocfs2     _netdev,defaults  0 0\" >> /etc/fstab"
LN

exec_cmd mount $mount_point
LN
