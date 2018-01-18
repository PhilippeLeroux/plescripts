#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage :
$ME
	-pdb=name"

typeset		pdb=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

#ple_enable_log -params $PARAMS

# $1 user name
function sql_drop_user_cascade
{
	set_sql_cmd "drop user $1 cascade;"
}

# close pdb $1
function sql_close_pdb
{
	set_sql_cmd "alter pluggable database $1 close immediate instances=all;"
}

# open pdb $1
function sql_open_pdb
{
	set_sql_cmd "alter pluggable database $1 open instances=all;"
}

must_be_user oracle

exit_if_ORACLE_SID_not_defined

exit_if_param_undef pdb "$str_usage"

typeset	-r	conn_str="sys/$oracle_password@$(hostname -s):1521/$pdb as sysdba"

for user in hr bi oe pm ix sh
do
	sqlplus_cmd_with "$conn_str" "$(sql_drop_user_cascade $user)"
	LN
done

sqlplus_cmd "$(sql_close_pdb $pdb)"
LN
sleep 2
sqlplus_cmd "$(sql_open_pdb $pdb)"
LN
