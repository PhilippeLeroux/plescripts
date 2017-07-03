#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

Utile, par exemple, quand la création d'un PDB foire."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

#ple_enable_log -params $PARAMS

# $1 service permettant de se connecter à la Primary Database
function primary_archive_log_current
{
	typeset s_name="$1"
	line_separator
	info "Switch archive log on Primary $s_name"
	# Si le répertoire des archivelogs du jour est supprimé, la commande échoue.
	function sqlcmd_archive_log
	{
		set_sql_cmd "whenever sqlerror exit 1;"
		set_sql_cmd "alter system switch logfile;"
		set_sql_cmd "alter system archive log current;"
	}
	sqlplus_cmd_with "sys/$oracle_password@$s_name as sysdba" "$(sqlcmd_archive_log)"
	ret=$?
	LN
	[ $ret -ne 0 ] && exit 1 || true
}

function stby_recover_database_until_consistent
{
	function sql_cmds
	{
		set_sql_cmd "recover managed standby database cancel;"
		set_sql_cmd "recover managed standby database until consistent;"
		set_sql_cmd "recover managed standby database disconnect;"
	}

	line_separator
	info "Recover standby database until consistent."
	sqlplus_cmd "$(sql_cmds)"
	LN
}

exit_if_ORACLE_SID_not_defined

typeset	-r	primary_db_name="$(read_primary_name)"
typeset	-r	db="$(orcl_parameter_value db_unique_name)"
typeset -r	dbrole="$(read_database_role $db)"

info "Database $db role $dbrole"
if [ "$dbrole" != "physical" ]
then
	error "role must be physical."
	LN
	exit 1
fi
info "Primary database : $primary_db_name"
LN

primary_archive_log_current $primary_db_name

stby_recover_database_until_consistent

exec_cmd "dgmgrl -silent -echo sys/Oracle12 'show database $db'"
LN
