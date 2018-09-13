#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME
	-db=name       Identifier.
	[-dg_node=#]   Dataguard node
	[-no_crs]      No Grid Infra.
"

typeset		db=undef
typeset	-i	dg_node=-1
typeset		crs=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-dg_node=*)
			dg_node=${1##*=}
			shift
			;;

		-no_crs)
			crs=no
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

exit_if_param_undef db		"$str_usage"

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

if [ $dg_node -eq -1 ]
then
	info "Load node $db 1"
	LN
	cfg_load_node_info $db 1
else
	info "Load dataguard node $db 1"
	LN
	cfg_load_node_info $db $dg_node
fi

typeset	-r	first_vm=$cfg_server_name

if [ $cfg_db_type == rac ]
then
	for (( inode=2; inode <= max_nodes; ++inode ))
	do
		cfg_load_node_info $db $inode
		attach_to="$attach_to $cfg_server_name"
	done
else
	typeset	-r	attach_to=no_attach
fi

if [ "$vm_path" == "$db_disk_path" ]
then
	typeset	-r	disk_path=default
else
	if [ $cfg_dataguard == no ]
	then
		typeset	-r	disk_path="$db_disk_path/$db"
	else
		typeset	-r	disk_path="$(printf "%s%02d" "$db_disk_path/$db" $dg_node)"
	fi
	exec_cmd "mkdir -p '$disk_path'"
	LN
fi

typeset	-r	cfg_disk=$cfg_path_prefix/$db/disks
typeset	-i	ilun=1 # Indice pour tous les disks de tous les DG.
while IFS=: read dg_name size_gb first_no last_no
do
	line_separator
	typeset	-i	nr_disks=last_no-first_no+1
	info "Add $nr_disks disks for DG $dg_name"
	typeset	-i	size_mb=size_gb*1024
	for (( idisk=1; idisk <= nr_disks; ++idisk ))
	do
		exec_cmd ~/plescripts/virtualbox/add_disk.sh						\
							-vm_name=$first_vm								\
							-disk_name=$(printf "%s_disk%02d" $db $ilun)	\
							-disk_mb=$size_mb								\
							-attach_to="'$attach_to'"						\
							-disk_path="$disk_path"							\
							-fixed_size
		((++ilun))
	done
	LN
done<$cfg_disk
