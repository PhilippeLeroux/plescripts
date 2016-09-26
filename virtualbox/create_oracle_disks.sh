#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=name"

info "Running : $ME $*"

typeset		db=undef

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

typeset -r cfg_path=~/plescripts/database_servers/$db
[ ! -d $cfg_path ] && error "Directory $cfg_path not exists." && exit 1

typeset	-r	db_type=$(cat $cfg_path/node1 | cut -d: -f1)
if [ $db_type == rac ]
then
	typeset	-i	inode=0
	for node_file in $cfg_path/node*
	do
		if [ $inode -eq 0 ]
		then
			first_vm=$(cat $node_file | cut -d: -f2)
		else
			attach_to="$attach_to $(cat $node_file | cut -d: -f2)"
		fi
		inode=inode+1
	done
else
	first_vm=$(cat $cfg_path/node1 | cut -d: -f2)
	typeset	-r	attach_to=no_attach
fi

typeset	-i	ilun=1
while IFS=: read dg_name size_gb first_no last_no
do
	count=$(( last_no - first_no + 1 ))
	info "Add $count disks for DG $dg_name"
	typeset -i	size_mb=$(( size_gb * 1024 ))
	for idisk in $( seq $count )
	do
		exec_cmd ~/plescripts/virtualbox/add_disk.sh					\
							-vm_name=$first_vm							\
							-disk_name=$(printf "%s_lun%02d" $db $ilun)	\
							-disk_mb=$size_mb							\
							-attach_to=\"$attach_to\"
							-fixed_size
		ilun=ilun+1
	done
done<$cfg_path/disks
