#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-device=name         OS disk name or auto.
	-vg=name             VG name, for exemple asm01
	[-add_partition=no]  yes|no, yes : add a partition to device.
	[-io_scheduler=none] noop|deadline|cfq create udev rule for device
"

script_banner $ME $*

typeset	device=undef
typeset vg=undef
typeset	add_partition=no

typeset	io_scheduler=none

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
			device=${device##*/}
			shift
			;;

		-vg=*)
			vg=${1##*=}
			shift
			;;

		-add_partition=*)
			add_partition=$(to_lower ${1##*=})
			shift
			;;

		-io_scheduler=*)
			io_scheduler=$(to_lower ${1##*=})
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

exit_if_param_undef device	"$str_usage"
exit_if_param_undef vg		"$str_usage"

exit_if_param_invalid add_partition "yes no" "$str_usage"
exit_if_param_invalid io_scheduler "none noop deadline cfq" "$str_usage"

#	exit if device $1 not exists
function exit_if_device_not_exists
{
	typeset -r device=$1

	info "Test if $device exists."
	exec_cmd -f -ci "lvmdiskscan | grep -q $device"
	if [ $? -ne 0 ]
	then
		error "Device '$device' not exists."
		LN

		info "$str_usage"
		exit 1
	fi
}

function exit_if_vg_exists
{
	typeset -r vg_name=$1

	info "Test if $vg_name not exists."
	exec_cmd -f -ci "vgdisplay $vg_name >/dev/null 2>&1"
	if [ $? -eq 0 ]
	then
		error "$vg_name exists !"
		LN

		info "$str_usage"
		LN
		exit 1
	fi
}

if [ $device == auto ]
then
	line_separator
	info "Search unused disk..."
	device=$(get_unused_disks_without_partitions | head -1)
	if [ x"$device" == x ]
	then
		error "No disk unused found."
		exit 1
	fi
	device=${device##*/}
	info "Disk found : $device"
	LN
fi

line_separator
info "Create VG $vg on device $device"
line_separator
LN

#	Test utile si device != auto
exit_if_device_not_exists $device
LN

exit_if_vg_exists $vg
LN

device=/dev/$device

if [ $add_partition == yes ]
then
	add_partition_to $device
	sleep 1
	LN

	device=${device}1
fi

exec_cmd "pvcreate $device"
LN

exec_cmd "vgcreate $vg $device"
LN

exec_cmd "vgdisplay $vg"
LN

if [ $io_scheduler != none ]
then
	exec_cmd ~/plescripts/disk/create_udev_rule_io_scheduler.sh		\
											-device_list=$device	\
											-io_scheduler=$io_scheduler
fi
