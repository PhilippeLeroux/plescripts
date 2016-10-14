#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=<str> -vm_memory_mb=<#> [-vmGroup=<name>]"

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

		-vmGroup=*)
			vmGroup="${1##*=}"
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

cfg_exist $db

typeset		node_list
typeset -ri max_nodes=$(cfg_max_nodes $db)
#	ici le n° du nœud n'est pas important et il y a toujours un nœud 1.
cfg_load_node_info $db 1

if [ x"$vmGroup" == x ]
then
	case $cfg_db_type in
		std)
			typeset	-r	group_name="/Standalone $(initcap $db)"
			;;

		rac)
			typeset	-r	group_name="/RAC $(initcap $db)"
			;;
	esac
else
	typeset	-r	group_name="$vmGroup"
fi

for nr_node in $( seq $max_nodes )
do
	cfg_load_node_info $db $nr_node
	typeset	vm_name=$cfg_server_name

	if [ $nr_node -ne 1 ]
	then
		[ x"$node_list" == x ] && node_list=$vm_name || node_list="$node_list $vm_name"
	fi

	info "Clone $vm_name from $master_name"
	exec_cmd VBoxManage clonevm "$master_name"		\
						--name "$vm_name"			\
						--basefolder \"$vm_path\"	\
						--register
	LN

	exec_cmd VBoxManage modifyvm "$vm_name" --memory $vm_memory_mb
	exec_cmd VBoxManage modifyvm $vm_name --cpus 2
	exec_cmd "VBoxManage modifyvm $vm_name --description \"$(~/plescripts/virtualbox/vbox_desc -db=$db)\""
	LN

	info "Test pour voir si perf réseau meilleurs :"
	exec_cmd VBoxManage modifyvm "$vm_name" --hpet on
	LN

	if [ $type_shared_fs == vbox ]
	then
		exec_cmd VBoxManage sharedfolder add $vm_name							\
										--name \"${oracle_release%.*.*}\"		\
										--hostpath \"$HOME/$oracle_install\"	\
										--automount
		LN
	fi

	info "Move $vm_name to group $group_name"
	exec_cmd VBoxManage modifyvm "$vm_name" --groups \"$group_name\" || true
	LN

	case $cfg_db_type in
			std)
				info "Create disk ${vm_name}_u01 for mount point /u01"
				exec_cmd $vm_scripts_path/add_disk.sh	-vm_name="$vm_name"			\
														-disk_name=${vm_name}_u01	\
														-disk_mb=$((20*1024))		\
														-fixed_size
				LN
				;;

			rac)
				if [ $rac_u01_fs == ocfs2 ]
				then
					info "Create disk ${vm_name}_u02 for mount point /u02 for grid"
					exec_cmd $vm_scripts_path/add_disk.sh						\
											-vm_name="$vm_name"			\
											-disk_name=${vm_name}_u02	\
											-disk_mb=$((10*1024))				\
											-fixed_size

				else
					info "Create disk ${vm_name}_u01 for mount point /u01"
					exec_cmd $vm_scripts_path/add_disk.sh	-vm_name="$vm_name"			\
															-disk_name=${vm_name}_u01	\
															-disk_mb=$((20*1024))		\
															-fixed_size
					LN
				fi
				;;
	esac

	# Présent ici car dans setup_first_vms/vbox_scripts/01_create_master_vm.sh
	# le Guru apparaît toujours.
	# Même ici ne marche pas à tout les coups.
	exec_cmd VBoxManage setextradata "$vm_name" GUI/GuruMeditationHandler PowerOff
	LN
done

if [[ $cfg_db_type == rac && $rac_u01_fs == ocfs2 ]]
then # Avec ocfs2 /u01 est partagé par tous les nœuds.
	cfg_load_node_info $db 1

	info "Create shared disk ${cfg_server_name}_u01 for mount point /u01 for oracle"
	exec_cmd $vm_scripts_path/add_disk.sh	-vm_name="$cfg_server_name"			\
											-disk_name=${cfg_server_name}_u01	\
											-disk_mb=$((10*1024))				\
											-attach_to="'$node_list'"			\
											-fixed_size
	LN
fi

[ $cfg_luns_hosted_by == san ] && exit 0

exec_cmd "~/plescripts/virtualbox/create_oracle_disks.sh -db=$db"
