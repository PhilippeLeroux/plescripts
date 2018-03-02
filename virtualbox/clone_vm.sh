#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME
	-db=name           Identifier.
	-node=#            RAC/Dataguard node number
	-vm_memory_mb=#    RAM for VM.
	[-vmGroup=name]    Group name for VM.
"

typeset		db=undef
typeset	-i	node=-1
typeset	-i	vm_memory_mb=-1
typeset		vmGroup=undef

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

		-node=*)
			node=${1##*=}
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
exit_if_param_undef node			"$str_usage"
exit_if_param_undef vm_memory_mb	"$str_usage"

cfg_exists $db

typeset		node_list
typeset -ri max_nodes=$(cfg_max_nodes $db)

cfg_load_node_info $db	$node

if [[ "$vmGroup" != undef && ${vmGroup:0:1} != '/' ]]
then
	vmGroup="/$vmGroup"
fi

if [ $cfg_db_type == rac ]
then
	typeset -r nr_cpus=$vm_nr_cpus_for_rac_db
else
	typeset -r nr_cpus=$vm_nr_cpus_for_single_db
fi

for (( nr_node = $node; nr_node <= $max_nodes; ++nr_node ))
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
	if [ "$hpet" == on ]
	then
		exec_cmd VBoxManage modifyvm $vm_name --hpet on
	fi
	exec_cmd "VBoxManage modifyvm $vm_name	\
		--description \"$(~/plescripts/virtualbox/get_vm_description -db=$db)\""
	LN

	if [ "$vmGroup" != undef ]
	then
		info "Move $vm_name to group $vmGroup"
		exec_cmd VBoxManage modifyvm "$vm_name" --groups \"$vmGroup\"
		LN
	fi

	if [ $cfg_db_type != fs ]
	then
		info "Create disk ${vm_name}_$grid_disk for mount point /$grid_disk for grid"
		exec_cmd $vm_scripts_path/add_disk.sh								\
								-vm_name="$vm_name"							\
								-disk_name=${vm_name}_$grid_disk			\
								-disk_mb=$(( grid_disk_size_gb * 1024 ))	\
								-fixed_size
		LN

		if [[ $cfg_db_type != rac || $cfg_oracle_home != ocfs2 ]]
		then	# Si utilisation de ocfs2 les disques sont crées après la création
				# de tous les serveurs.
			info "Create disk ${vm_name}_$orcl_disk for mount point /$orcl_disk for Oracle"
			exec_cmd $vm_scripts_path/add_disk.sh							\
								-vm_name="$vm_name"							\
								-disk_name=${vm_name}_$orcl_disk			\
								-disk_mb=$(( orcl_disk_size_gb * 1024 ))	\
								-fixed_size
			LN
		fi
	else
		# Si le Grid n'est pas installé il n'y a besoin que d'un seul disque.
		info "Create disk ${vm_name}_$orcl_sw_fs_disk for mount point /$orcl_sw_fs_disk for Oracle"
		exec_cmd $vm_scripts_path/add_disk.sh								\
								-vm_name="$vm_name"							\
								-disk_name=${vm_name}_$orcl_sw_fs_disk		\
								-disk_mb=$(( orcl_sw_fs_size_gb * 1024 ))	\
								-fixed_size
		LN
	fi

	exec_cmd VBoxManage setextradata "$vm_name" GUI/GuruMeditationHandler PowerOff
	LN

	[ $cfg_db_type != rac ] && break || true
done

if [[ $cfg_db_type == rac && $cfg_oracle_home == ocfs2 ]]
then # Avec ocfs2 le disque Oracle est partagé par tous les nœuds.
	cfg_load_node_info $db 1

	info "Create shared disk ${cfg_server_name}_$orcl_disk for mount point /$orcl_disk for oracle"
	exec_cmd $vm_scripts_path/add_disk.sh									\
								-vm_name="$cfg_server_name"					\
								-disk_name=${cfg_server_name}_$orcl_disk	\
								-disk_mb=$(( orcl_disk_size_gb * 1024 ))	\
								-attach_to="'$node_list'"					\
								-fixed_size
	LN
fi

[ $cfg_luns_hosted_by == san ] && exit 0 || true

if [ $cfg_dataguard == yes ]
then
	exec_cmd "$vm_scripts_path/create_oracle_disks.sh -db=$db -dg_node=$node"
else
	exec_cmd "$vm_scripts_path/create_oracle_disks.sh -db=$db"
fi
