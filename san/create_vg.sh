#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME 
	[-device=sdb] Nom du disque à utiliser, par défaut sdb.
	[-vg=asm01]   Nom du VG à créer par défaut asm01.

Lors de la création de la VM K2 sont attachés 2 disques, le second disque sdb
est pour le vg asm01.

Pour créer un autre VG sur un autre disque spécifier les arguments.
"

info "$ME $@"

typeset	device=sdb
typeset vg=asm01

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

