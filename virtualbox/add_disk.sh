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
	[-attach_to]    Ex : 'vm1 vm2'
	[-fixed_size]   Disque taille fixe (automatique si -attach_to est précisé.)
"

info "Running : $ME $*"

typeset		vm_name=undef
typeset		disk_name=undef
typeset	-i	disk_mb=-1
typeset		attach_to=no_attach
typeset		fixed_size=Standard

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

		-attach_to=*)
			attach_to=${1##*=}
			shift
			;;

		-fixed_size)
			fixed_size=Fixed
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
	typeset -ri nu=$(grep -E "^SATA"  /tmp/${vm_name}.info | sed "s/SATA (\([0-9]*\),.*/\1/" | tail -1)
	rm -f /tmp/${vm_name}.info
	echo $(( nu+1 ))
}

typeset	-r	disk_full_path="$vm_path/$vm_name/${disk_name}.vdi"

typeset -r on_port=$(get_free_SATA_port)
if [ "$attach_to" == no_attach ]
then
	mtype=normal
	attach_to=$vm_name
	variant=$fixed_size
else
	mtype=shareable
	attach_to="$vm_name $attach_to"
	variant=Fixed
fi


line_separator
if [ ! -d "$disk_full_path" ]
then
	info "Create disk : '$disk_full_path'"
	exec_cmd VBoxManage createhd						\
						--filename \"$disk_full_path\"	\
						--size $disk_mb --variant=$variant
	LN
fi

for vm in $attach_to
do
	info "Attach disk to $vm on port '$on_port'"
	exec_cmd VBoxManage storageattach $vm				\
						--storagectl SATA				\
						--port $on_port					\
						--device 0						\
						--type hdd						\
						--mtype	$mtype					\
						--medium \"$disk_full_path\"
	LN
done
