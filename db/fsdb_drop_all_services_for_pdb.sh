#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
"

script_banner $ME $*

typeset	db=undef
typeset	pdb=undef

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

		-pdb=*)
			pdb=${1##*=}
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

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_ORACLE_SID_not_defined

info "$db : drop services for pdb $pdb"
LN

function sql_query_read_service
{
	sqlplus -s sys/$oracle_password@localhost:1521/$pdb as sysdba<<EOS
set echo off
set feed off
set heading off
select
	name
from
	dba_services
where
	name like '%oci' or name like '%java'
;
EOS
}

typeset db_role="$(read_database_role $db)"
[ x"$db_role" == x ] && db_role=primary || true

while read service_name
do
	[ x"$service_name" == x ] && continue || true

	function sql_drop_service
	{
		set_sql_cmd "alter session set container=$1;"
		set_sql_cmd "exec dbms_service.stop_service( '$2' );"
		set_sql_cmd "exec dbms_service.delete_service( '$2' );"
	}
	line_separator
	info "$pdb : $service_name"
	if [ $db_role == primary ]
	then
		sqlplus_cmd "$(sql_drop_service $pdb $service_name)"
		LN
	fi
	exec_cmd ~/plescripts/db/delete_tns_alias.sh -tnsalias=$service_name
	LN
done<<<"$(sql_query_read_service)"

line_separator
sqlplus_cmd "$(set_sql_cmd "alter system register;")"
LN
