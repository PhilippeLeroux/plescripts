#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=<str> -vm_memory_mb=<#>"

info "Running : $ME $*"

typeset		db=undef
typeset	-i	vm_memory_mb=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-vm_memory_mb=*)
			vm_memory_mb=${1##*=}
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

exit_if_param_undef db				"$str_usage"
exit_if_param_undef vm_memory_mb	"$str_usage"

typeset -r	cfg_path=~/plescripts/database_servers/$db
exit_if_dir_not_exists $cfg_path "$str_usage"

typeset -ri	max_nodes=$(ls -1 $cfg_path/node*|wc -l)

typeset	-r	db_type=$(cat $cfg_path/node1 | cut -d: -f1)
case $db_type in
	std)
		typeset	-r	group_name="/Standalone $(initcap $db)"
		;;

	rac)
		typeset	-r	group_name="/RAC $(initcap $db)"
		;;
esac

for node_file in $cfg_path/node*
do
	typeset	vm_name=$(cat $node_file | cut -d: -f2)

	info "Clone $vm_name from $master_name"
	exec_cmd VBoxManage clonevm "$master_name" --name "$vm_name" --basefolder \"$vm_path\" --register
	exec_cmd VBoxManage modifyvm "$vm_name" --memory $vm_memory_mb
	exec_cmd VBoxManage storageattach "$vm_name" --storagectl IDE  --port 1 --device 0 --type dvddrive --medium emptydrive

	if [ $type_shared_fs == vbox ]
	then
		exec_cmd VBoxManage sharedfolder add $vm_name --name \"${oracle_release%.*.*}\" --hostpath \"$HOME/$oracle_install\" --automount
	fi

	exec_cmd VBoxManage modifyvm "$vm_name" --groups \"$group_name\" || true
	# Présent ici car dans setup_first_vms/vbox_scripts/01_create_master_vm.sh
	# le Guru apparaît toujours.
	# Ne marche pas à tout les coups.
	exec_cmd VBoxManage setextradata "$vm_name" GUI/GuruMeditationHandler PowerOff
	LN
done
