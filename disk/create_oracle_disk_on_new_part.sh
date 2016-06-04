#!/bin/ksh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-skip_errors]
	Recherche les partitions qui ne sont pas utilisées par oracleasm
	et les donnes à oracleasm.
"
typeset	skip_errors=no

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

		-skip_errors)
			skip_errors=yes;
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
			LN

			exit 1
			;;
	esac
done

# BUG :
#	Si des devices iscsi ont été crées avant les devices iscsi pour oracle
#	alors les disques oracle n'auront pas les bons labels. Les n° des disques
#	seront décalés.
#
# Finalement pas de correction envisagées, le problème ne se pause qu'à
# l'installation.
# Le près requis est donc que l'installation se fait sur un serveur neuf !
function map_devices
{
	exec_cmd "oracleasm scandisks"
	LN

	typeset -r hostn=$(hostname -s)
	typeset -r db=$( echo $hostn | sed "s/...\(.*\)..$/\1/" )

	typeset -i	count_disks_used=0
	typeset -i	count_added_oracle_disks=0

	get_iscsi_disks |\
	while read disk_name disk_num
	do
		info "Disk $disk_nun : $disk_name"
		part_name=${disk_name}1
		if [ -b $part_name ]
		then
			oracleasm querydisk $part_name >/dev/null 2>&1
			if [ $? -eq 0 ]
			then
				info "	used."
				count_disks_used=count_disks_used+1
				LN
			else
				oracle_label=$(printf "s1disk${db}%02d" $disk_num)
				info "create $oracle_label on $part_name"
				exec_cmd -c "oracleasm createdisk $oracle_label ${part_name}"
				# BUG: $skip_errors = false !?
				if [ $? -ne 0 ] && [ $skip_errors = yes ]
				then
					error "abort !"
					exit 1
				fi
				count_added_oracle_disks=count_added_oracle_disks+1
				LN
			fi
		else
			info "Partition $part_name not exists."
			LN
		fi
	done

	exec_cmd "oracleasm scandisks"
	LN

	exec_cmd "oracleasm listdisks"
	LN

	info "$count_added_oracle_disks oracle disks added."
}

line_separator
map_devices
LN
