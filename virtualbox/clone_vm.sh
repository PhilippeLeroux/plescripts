#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME
	-db=name           Identifier.
	-vm_memory_mb=#    RAM for VM.
	[-vmGroup=name]    Group name for VM.
"

script_banner $ME $*

typeset		db=undef
typeset	-i	vm_memory_mb=-1
typeset		vmGroup

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

cfg_exists $db

typeset		node_list
typeset -ri max_nodes=$(cfg_max_nodes $db)
#	ici le n° du nœud n'est pas important et il y a toujours un nœud 1.
cfg_load_node_info $db 1

if [ x"$vmGroup" == x ]
then
	case $cfg_db_type in
		std|fs)
			typeset	-r	group_name="/Standalone $(initcap $db)"
			;;

		rac)
			typeset	-r	group_name="/RAC $(initcap $db)"
			;;
	esac
else
	typeset	-r	group_name="$vmGroup"
fi

if [ $max_nodes -eq 1 ]
then
	typeset -r nr_cpus=$vm_nr_cpus_for_single_db
else
	typeset -r nr_cpus=$vm_nr_cpus_for_rac_db
fi

for nr_node in $( seq $max_nodes )
do
	cfg_load_node_info $db $nr_node
	typeset	vm_name=$cfg_server_name

	if [ $nr_node -ne 1 ]
	then
		[ x"$node_list" == x ] && node_list=$vm_name || node_list="$node_list $vm_name"
	fi

	info "Clone $vm_name from $master_hostname"
	exec_cmd VBoxManage clonevm "$master_hostname"		\
							--name "$vm_name"			\
							--basefolder \"$vm_path\"	\
							--register
	LN

	exec_cmd VBoxManage modifyvm "$vm_name" --memory $vm_memory_mb
	exec_cmd VBoxManage modifyvm $vm_name --cpus $nr_cpus
	exec_cmd VBoxManage modifyvm $vm_name --hpet $hpet
	exec_cmd "VBoxManage modifyvm $vm_name	\
		--description \"$(~/plescripts/virtualbox/get_vm_description -db=$db)\""
	LN

	info "Move $vm_name to group $group_name"
	exec_cmd VBoxManage modifyvm "$vm_name" --groups \"$group_name\"
	LN

	if [ $cfg_db_type != fs ]
	then
		info "Create disk ${vm_name}_$GRID_DISK for mount point /$GRID_DISK for grid"
		exec_cmd $vm_scripts_path/add_disk.sh								\
								-vm_name="$vm_name"							\
								-disk_name=${vm_name}_$GRID_DISK			\
								-disk_mb=$(( GRID_DISK_SIZE_GB * 1024 ))	\
								-fixed_size
		LN

		if [[ $cfg_db_type != rac || $cfg_oracle_home != ocfs2 ]]
		then	# Si utilisation de ocfs2 les disques sont crées après la création
				# de tous les serveurs.
			info "Create disk ${vm_name}_$ORCL_DISK for mount point /$ORCL_DISK for Oracle"
			exec_cmd $vm_scripts_path/add_disk.sh							\
								-vm_name="$vm_name"							\
								-disk_name=${vm_name}_$ORCL_DISK			\
								-disk_mb=$(( ORCL_DISK_SIZE_GB * 1024 ))	\
								-fixed_size
			LN
		fi
	else
		# Si le Grid n'est pas installé il n'y a besoin que d'un seul disque.
		info "Create disk ${vm_name}_$ORCL_SW_FS_DISK for mount point /$ORCL_SW_FS_DISK for Oracle"
		exec_cmd $vm_scripts_path/add_disk.sh								\
								-vm_name="$vm_name"							\
								-disk_name=${vm_name}_$ORCL_SW_FS_DISK		\
								-disk_mb=$(( ORCL_SW_FS_SIZE_GB * 1024 ))	\
								-fixed_size
		LN
	fi

	# Présent ici car dans setup_first_vms/vbox_scripts/01_create_master_vm.sh
	# le Guru apparaît toujours.
	# Même ici ne marche pas à tout les coups.
	exec_cmd VBoxManage setextradata "$vm_name" GUI/GuruMeditationHandler PowerOff
	LN
done

if [[ $cfg_db_type == rac && $cfg_oracle_home == ocfs2 ]]
then # Avec ocfs2 le disque Oracle est partagé par tous les nœuds.
	cfg_load_node_info $db 1

	info "Create shared disk ${cfg_server_name}_$ORCL_DISK for mount point /$ORCL_DISK for oracle"
	exec_cmd $vm_scripts_path/add_disk.sh									\
								-vm_name="$cfg_server_name"					\
								-disk_name=${cfg_server_name}_$ORCL_DISK	\
								-disk_mb=$(( ORCL_DISK_SIZE_GB * 1024 ))	\
								-attach_to="'$node_list'"					\
								-fixed_size
	LN
fi

[ $cfg_luns_hosted_by == san ] && exit 0 || true

exec_cmd "~/plescripts/virtualbox/create_oracle_disks.sh -db=$db"
