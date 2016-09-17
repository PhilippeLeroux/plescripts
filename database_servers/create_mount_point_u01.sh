#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -device=str"

info "Running : $ME $*"

typeset device=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-device=*)
			device=${1##*=}
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

exit_if_param_undef device "$str_usage"

typeset	-r	vg_name=vgorcl
typeset	-r	lv_name=lvorcl
typeset	-r	u01_fs_type=xfs

typeset	-r	part_name=${device}1

if [ "$(disk_type $device)" != "unused" ]
then
	error "device $device used."
	exit 1
fi

add_partition_to $device
exec_cmd pvcreate $part_name
exec_cmd vgcreate $vg_name $part_name
exec_cmd lvcreate -y -l 100%FREE -n $lv_name $vg_name
exec_cmd mkfs -t $u01_fs_type /dev/$vg_name/$lv_name
exec_cmd mkdir /u01
exec_cmd "echo \"/dev/mapper/$vg_name-$lv_name /u01 $u01_fs_type defaults 0 0\" >> /etc/fstab"
exec_cmd mount /u01
