#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME"

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
			info "$str_usage"
			exit 1
			;;
	esac
done

#ple_enable_log

script_banner $ME $*

function sql_bounce
{
	set_sql_cmd "shutdown immediate;"
	set_sql_cmd "startup;"
}

if command_exists crsctl
then
	typeset -r db_name=$(srvctl config database)
	exec_cmd srvctl stop database -db $db_name
	LN

	exec_cmd srvctl start database -db $db_name
	LN
else
	exit_if_ORACLE_SID_not_defined

	sqlplus_cmd "$(sql_bounce)"
	LN
fi

line_separator
sqlplus_cmd "$(set_sql_cmd "@$HOME/plescripts/db/sql/lspdbs.sql")"
LN
