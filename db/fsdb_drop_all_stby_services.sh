#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=name"

script_banner $ME $*

typeset	db=undef

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

exit_if_param_undef db	"$str_usage"

exit_if_ORACLE_SID_not_defined

typeset query=\
"select
	name
from
	v\$pdbs
where
	name != 'PDB\$SEED'
;"

while read pdb
do
	[ x"$pdb" == x ] && continue || true
	[ "${pdb:0:4}" == "SQL>" ] && continue || true

	function sql_drop_service
	{
		set_sql_cmd "alter session set container=$1;"
		set_sql_cmd "exec dbms_service.stop_service( '$2' );"
		set_sql_cmd "exec dbms_service.delete_service( '$2' );"
	}
	srv=$(mk_oci_stby_service $pdb)
	info "$pdb : $srv"
	sqlplus_cmd "$(sql_drop_service $pdb $srv)"
	srv=$(mk_java_stby_service $pdb)
	info "$pdb : $srv"
	sqlplus_cmd "$(sql_drop_service $pdb $srv)"
	LN
	sqlplus_cmd "$(set_sql_cmd "alter system register;")"
	LN
done<<<"$(sqlplus_exec_query "$(set_sql_cmd $query)")"
