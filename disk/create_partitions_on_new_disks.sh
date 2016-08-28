#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh

. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	[-clear_partitions] Les partitions sont 'nettoyées' après création.
	[-emul]

	* scan les nouveaux disques iscsi.
	* création des partitions sur tous les disques iscsi non utilisés.
"

if [ $USER != root ]
then
	error "Only user root can execute this script."
	LN

	info "$str_usage"
	exit 1
fi

typeset	clear_partitions=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-clear_partitions)
			clear_partitions=yes
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
	typeset	-a partition_list

	info "Update iscsi luns"
	exec_cmd -f iscsiadm -m node --rescan
	LN

	info -n "Wait : "; pause_in_secs 5; LN
	LN

	info "Search disks without partition :"

	while read disk_name disk_num
	do
		part_name=${disk_name}1
		name_type=$(disk_type $disk_name)
		if [[ "$name_type" == "unused" ]]
		then
			typeset -i nb_part=$(count_partition_for $disk_name)
			if [ $nb_part -eq 0 ]
			then
				add_partition_to $disk_name
				partition_list[$count_new_part]=$part_name
				count_new_part=count_new_part+1
				LN
			else
				info "$disk_name partition exists."
				LN
			fi
		else
			info "$disk_name is $name_type"
			LN
		fi
	done<<<"$(get_iscsi_disks)"

	if [ $clear_partitions == yes ]
	then
		line_separator
		for ip in $( seq $count_new_part )
		do
			clear_device ${partition_list[ip-1]}
			LN
		done
	fi

	info "$count_new_part partitions added."
}

line_separator
create_partitions
LN
