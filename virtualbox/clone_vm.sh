#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
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

typeset -ri max_nodes=$(cfg_max_nodes $db)
#	ici le n° du noeud n'est pas important et il y a tjr un noeud 1.
cfg_load_node_info $db 1

case $cfg_db_type in
	std)
		typeset	-r	group_name="/Standalone $(initcap $db)"
		;;

	rac)
		typeset	-r	group_name="/RAC $(initcap $db)"
		;;
esac

#for node_file in $cfg_path/node*
for nr_node in $( seq $max_nodes )
do
	cfg_load_node_info $db $nr_node
	typeset	vm_name=$cfg_server_name

	info "Clone $vm_name from $master_name"
	exec_cmd VBoxManage clonevm "$master_name"		\
						--name "$vm_name"			\
						--basefolder \"$vm_path\"	\
						--register
	LN

	exec_cmd VBoxManage modifyvm "$vm_name" --memory $vm_memory_mb
	exec_cmd VBoxManage modifyvm $vm_name --cpus 2
	LN
	

	if [ $type_shared_fs == vbox ]
	then
		exec_cmd VBoxManage sharedfolder add $vm_name							\
										--name \"${oracle_release%.*.*}\"		\
										--hostpath \"$HOME/$oracle_install\"	\
										--automount
		LN
	fi

	info "Create disk ${vm_name}_u01 for mount point /u01"
	exec_cmd VBoxManage modifyvm "$vm_name" --groups \"$group_name\" || true
	LN

	exec_cmd $vm_scripts_path/add_disk.sh	-vm_name="$vm_name"			\
											-disk_name=${vm_name}_u01	\
											-disk_mb=$((32*1024))
	LN

	# Présent ici car dans setup_first_vms/vbox_scripts/01_create_master_vm.sh
	# le Guru apparaît toujours.
	# Même ici ne marche pas à tout les coups.
	exec_cmd VBoxManage setextradata "$vm_name" GUI/GuruMeditationHandler PowerOff
	LN
done

[ $cfg_luns_hosted_by == san ] && exit 0

exec_cmd "~/plescripts/virtualbox/create_oracle_disks.sh -db=$db"
