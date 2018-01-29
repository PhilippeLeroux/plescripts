#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"
typeset	-r	str_usage=\
"Usage : $ME"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

script_start

must_be_user oracle

if command_exists crsctl
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

if [[ $crs_used == no || $gi_count_nodes -lt 2 ]]
then
	exit_if_ORACLE_SID_not_defined
	typeset	-r	conn_str=sys/$oracle_password
else
	# Dans le cas d'un RAC le backup se fera sur l'instance la moins chargée.
	db=$(crsctl stat res		|\
				grep "\.db$"	|\
				sed "s/NAME=ora\.\(.*\).db/\1/")
	if ! tnsping $db >/dev/null 2>&1
	then
		error "Cannot ping tns service $db"
		LN
		exit 1
	fi
	typeset	-r	conn_str=sys/$oracle_password@$db
fi

exec_cmd cd ~/plescripts/db/rman
LN

if [ $crs_used == no ]
then
	typeset -r disk_space_before="$(df -h /u0*)"
else
	typeset -r disk_space_before="$(~/plescripts/dg/dg_space.sh)"
fi

if is_oracle_enterprise_edition
then
	wait_if_high_load_average

	line_separator
	sqlplus_cmd_with $conn_str as sysdba "$(set_sql_cmd "@$HOME/plescripts/db/sql/show_corrupted_blocks.sql")"
	LN

	exec_cmd "rman target $conn_str @recover_corruption_list.rman"
	LN
fi

wait_if_high_load_average

line_separator
exec_cmd "rman target $conn_str @image_copy.rman"
LN

wait_if_high_load_average

line_separator
exec_cmd "rman target $conn_str @backup_archive_log.rman"
LN

wait_if_high_load_average 5

line_separator
exec_cmd "rman target $conn_str @crosscheck.rman"
LN

exec_cmd "cd -"
LN

line_separator
info "Espace disque avant backup :"
echo "$disk_space_before"

info "Espace disque après backup :"
if [ $crs_used == no ]
then
	LN
	exec_cmd "df -h /u0*"
	LN
else
	exec_cmd ~/plescripts/dg/dg_space.sh
fi

script_stop ${ME##*/} $ORACLE_SID
