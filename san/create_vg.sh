#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME 
	[-device=<str>] Nom du disque à utiliser, par exemple sdb.
	[-vg=<str>]     Nom du VG à créer par exemple asm01.
"

info "$ME $@"

typeset	device=undef
typeset vg=undef

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

		-vg=*)
			vg=${1##*=}
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

#	exit if device $1 not exists
function exit_if_device_not_exists
{
	typeset -r device=$1

	info "Test if $device exists."
	exec_cmd -f -ci "lvmdiskscan | grep $device >/dev/null 2>&1"
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

line_separator
info "Create VG $vg on device $device"
line_separator
LN

exit_if_device_not_exists $device
LN

exit_if_vg_exists $vg
LN

exec_cmd "pvcreate /dev/$device"
LN

exec_cmd "vgcreate $vg /dev/$device"
LN

exec_cmd "vgdisplay $vg"
LN

