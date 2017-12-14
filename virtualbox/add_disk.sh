#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-vm_name=name
	-disk_name=name
	-disk_mb=#
	[-attach_to]     Ex : 'vm1 vm2'
	[-mtype=auto] normal|writethrough|immutable|shareable|readonly|multiattach
	    auto : -attache_to specified -mtype=shareable else -mtype=normal
	[-fixed_size]    Disk size is fixed (auto with -attach_to)
	[-disk_path=name]

Add disk to SATA controller on the first free port, the controller must exists.
Disk is created if not exists.
"

typeset		vm_name=undef
typeset		disk_name=undef
typeset	-i	disk_mb=-1
typeset		attach_to=no_attach
typeset		mtype=auto
typeset		fixed_size=Standard
typeset		disk_path=default

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

		-mtype=*)
			mtype=${1##*=}
			shift
			;;

		-fixed_size)
			fixed_size=Fixed
			shift
			;;

		-disk_path=*)
			disk_path=${1##*=}
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

function get_free_SATA_port
{
	VBoxManage showvminfo $vm_name > /tmp/${vm_name}.info
	typeset -ri nu=$(grep -E "^SATA"  /tmp/${vm_name}.info | sed "s/SATA (\([0-9]*\),.*/\1/" | tail -1)
	rm -f /tmp/${vm_name}.info
	echo $(( nu+1 ))
}

# $1 vm name
# Affiche sur 1 le chemin contenant les fichiers de la VM.
#
# dupliquer de virtualbox/delete_vm
function read_vm_path_folder
{
	# Lecture du fichier de configuration
	typeset -r config_file=$(VBoxManage showvminfo $1	\
										| grep -E "^Config file:"|cut -d: -f2)
	# Tous les fichiers de la VM sont dans le même répertoire que config_file.
	sed "s/^ *//"<<<${config_file%/*}
}

# If "$@" begin with a ~, it's replaced by $HOME
function translate_tilde_to_home
{
	typeset	the_path="$@"
	[ ${the_path:0:1} == "~" ] && echo "$HOME${the_path:1}" || echo $the_path
}

if [ "$disk_path" == default ]
then
	typeset	-r disk_full_path="$(read_vm_path_folder $vm_name)/${disk_name}.vdi"
	info "Disks created to path '$disk_full_path'"
	LN
else
	disk_path=$(translate_tilde_to_home $disk_path)
	if [ ! -d "$disk_path" ]
	then
		error "Path '$disk_path' not exists."
		LN
		exit 1
	fi
	typeset	-r disk_full_path="$disk_path/${disk_name}.vdi"
fi

typeset -r	on_port=$(get_free_SATA_port)

if [ "$attach_to" == no_attach ]
then
	[ $mtype == auto ] && mtype=normal || true
	attach_to=$vm_name
	variant=$fixed_size
else
	[ $mtype == auto ] && mtype=shareable || true
	attach_to="$vm_name $attach_to"
	variant=Fixed
fi


line_separator
if [ ! -f "$disk_full_path" ]
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
