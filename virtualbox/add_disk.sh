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
	-disk_mb=#
"

info "Running : $ME $*"

typeset		vm_name=undef
typeset		disk_name=undef
typeset	-i	disk_mb=-1

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

		-disk_mb=*)
			disk_mb=${1##*=}
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
exit_if_param_undef disk_mb		"$str_usage"
exit_if_param_undef port		"$str_usage"

function get_free_SATA_port
{
	VBoxManage showvminfo $vm_name > /tmp/${vm_name}.info
	typeset -ri nu=$(grep -E "^SATA"  /tmp/${vm_name}.info | sed "s/SATA (\([0-9]\),.*/\1/" | tail -1)
	rm -f /tmp/${vm_name}.info
	echo $(( nu+1 ))
}

typeset	-r	disk_full_path="$vm_path/$vm_name/${disk_name}.vdi"

if [ ! -d "$disk_full_path" ]
then
	line_separator
	exec_cmd VBoxManage createhd						\
						--filename \"$disk_full_path\"	\
						--size $disk_mb
	LN
fi

line_separator
exec_cmd VBoxManage storageattach $vm_name			\
					--storagectl SATA				\
					--port $(get_free_SATA_port)	\
					--device 0						\
					--type hdd						\
					--medium \"$disk_full_path\"
LN
