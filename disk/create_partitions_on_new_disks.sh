#!/bin/ksh

#	ts=4 sw=4

#	rescan la session pour mapper les éventuelles nouvelles luns
#	crée une partition sur tous les disques n'en ayant pas.

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh

. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-emul]
	- scan les nouveaux disques iscsi.
	- crées des partitions sur tous les disques iscsi non utilisés.
"

if [ $USER != root ]
then
	error "Only user root can execute this script."
	LN

	info "$str_usage"
	exit 1
fi

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

			info $str_usage
			LN

		    exit 1
			;;
	esac
done

function create_partitions
{
	typeset -i count_new_part=0
	typeset -i count_existing_parts=0

	info "Update iscsi luns"
	exec_cmd -f iscsiadm -m node --rescan
	LN

	info "Search disks without partition :"

	get_iscsi_disks |\
	while read disk_name disk_num
	do
		part_name=${disk_name}1
		name_type=$(disk_type $disk_name)
		if [[ "$name_type" = "unused" ]]
		then
			count_partition_for $disk_name
			if [ $? -eq 0 ]
			then
				add_partition_to $disk_name
				count_new_part=$count_new_part+1
				LN
			else
				info "$disk_name partition exists."
				LN
			fi
		else
			info "$disk_name is $name_type"
			LN
		fi
	done

	info "$count_new_part partitions added."
	info "Total part : $(( $count_existing_parts + $count_new_part )) partitions"
}

line_separator
create_partitions
LN
