#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-vm_name=str
	-disk_name=str
	-new_size_mb=#

Attention la taille des disques ne peut être diminuée.
"

script_banner $ME $*

typeset		vm_name=undef
typeset		disk_name=undef
typeset	-i	new_size_mb=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-vm_name=*)
			vm_name=${1##*=}
			shift
			;;

		-disk_name=*)
			disk_name=${1##*=}
			shift
			;;

		-new_size_mb=*)
			new_size_mb=${1##*=}
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

exit_if_param_undef vm_name		"$str_usage"
exit_if_param_undef disk_name	"$str_usage"
exit_if_param_undef new_size_mb	"$str_usage"

typeset	-r	disk_full_path="$vm_path/$vm_name/${disk_name}.vdi"

exec_cmd VBoxManage modifymedium disk \"$disk_full_path\" --resize $new_size_mb
