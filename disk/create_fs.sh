#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-mount_point=name
	[-device=check]     or full device name : /dev/sdb
	-suffix_vglv=name   => vg\$suffix, lv\$suffix
	-type_fs=name
"

info "Running : $ME $*"

typeset mount_point=undef
typeset	device=check
typeset	suffix_vglv=undef
typeset	type_fs=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

		-suffix_vglv=*)
			suffix_vglv=${1##*=}
			shift
			;;

		-type_fs=*)
			type_fs=${1##*=}
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

exit_if_param_undef mount_point	"$str_usage"
exit_if_param_undef device		"$str_usage"
exit_if_param_undef suffix_vglv	"$str_usage"
exit_if_param_undef type_fs		"$str_usage"

typeset	-r	vg_name=vg${suffix_vglv}
typeset	-r	lv_name=lv${suffix_vglv}

if [ "$device" == check ]
then
	info "Search unused disk :"
	device=$(get_unused_disks | head -1)
	if [ x"$device" == x ]
	then
		error "No device found."
		exit 1
	fi
fi

typeset	-r	part_name=${device}1

info "Create fs $type_fs on device $device : mount point $mount_point"
LN

add_partition_to $device
exec_cmd pvcreate $part_name
exec_cmd vgcreate $vg_name $part_name
exec_cmd lvcreate -y -l 100%FREE -n $lv_name $vg_name
exec_cmd mkfs -t $type_fs /dev/$vg_name/$lv_name
exec_cmd mkdir -p $mount_point
exec_cmd "echo \"/dev/mapper/$vg_name-$lv_name $mount_point $type_fs defaults 0 0\" >> /etc/fstab"
exec_cmd mount $mount_point
