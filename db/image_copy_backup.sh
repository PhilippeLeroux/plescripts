#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
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

exit_if_ORACLE_SID_not_defined

script_start

if command_exists crsctl
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

exec_cmd cd ~/plescripts/db/rman
LN

if [ $crs_used == no ]
then
	typeset -r disk_space_before="$(df -h /u0*)"
fi

line_separator
sqlplus_cmd "$(set_sql_cmd "@$HOME/plescripts/db/sql/show_corrupted_blocks.sql")"
LN

exec_cmd "rman target sys/$oracle_password @recover_corruption_list.rman"
LN

line_separator
exec_cmd "rman target sys/$oracle_password @image_copy.rman"
LN

line_separator
exec_cmd "rman target sys/$oracle_password @backup_archive_log.rman"
LN

line_separator
exec_cmd "rman target sys/$oracle_password @crosscheck.rman"
LN

exec_cmd "cd -"
LN

if [ $crs_used == no ]
then
	line_separator
	info "Espace disque avant backup :"
	echo "$disk_space_before"
	LN

	info "Espace disque après backup :"
	exec_cmd "df -h /u0*"
	LN
fi

script_stop ${ME##/*}
