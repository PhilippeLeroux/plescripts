#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name  Identifier.
	[-no_crs] No Grid Infra.
"

script_banner $ME $*

typeset	db=undef
typeset	crs=yes

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

cfg_load_node_info $db 1
first_vm=$cfg_server_name

if [ $max_nodes -gt 1 ]
then
	for (( inode=2; inode <= max_nodes; ++inode ))
	do
		cfg_load_node_info $db $inode
		attach_to="$attach_to $cfg_server_name"
	done
else
	typeset	-r	attach_to=no_attach
fi

typeset -r	cfg_disk=$cfg_path_prefix/$db/disks
typeset	-i	ilun=1
while IFS=: read dg_name size_gb first_no last_no
do
	count=$(( last_no - first_no + 1 ))
	line_separator
	info "Add $count disks for DG $dg_name"
	typeset -i	size_mb=$(( size_gb * 1024 ))
	for (( idisk=1; idisk <= count; ++idisk ))
	do
		exec_cmd ~/plescripts/virtualbox/add_disk.sh					\
							-vm_name=$first_vm							\
							-disk_name=$(printf "%s_lun%02d" $db $ilun)	\
							-disk_mb=$size_mb							\
							-attach_to="'$attach_to'"					\
							-fixed_size
		((++ilun))
	done
	LN
done<$cfg_disk
