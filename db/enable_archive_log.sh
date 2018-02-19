#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/dblib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
$ME
	[-db=name] Database name, mandatory if Grid installed.
"
typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			rm -f $PLELIB_LOG_FILE
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

must_be_user oracle

exit_if_ORACLE_SID_not_defined

#	============================================================================
#	Fonctions fabriquant les commandes sql.

function sqlcmd_enable_archivelog
{
	set_sql_cmd "alter database archivelog;"

	set_sql_cmd "alter database open;"

	set_sql_cmd "archive log list;"
}

function sqlcmd_enable_archivelog_full_sqlplus
{
	set_sql_cmd "whenever sqlerror exit 1;"

	set_sql_cmd "shutdown immediate"

	set_sql_cmd "startup mount"

	sqlcmd_enable_archivelog
}

#	Active les archivelogs avec la commande sqlplus.
function enable_archivelog_without_GI
{
	sqlplus_cmd "$(sqlcmd_enable_archivelog_full_sqlplus)"
	LN
}

function sqlcmd_enable_archivelog_with_GI
{
	set_sql_cmd "whenever sqlerror exit 1;"

	sqlcmd_enable_archivelog

	set_sql_cmd "shutdown immediate"
}

#	Active les archivelogs quand le Grid Infra est présent (RAC possible).
function enable_archivelog_with_GI
{
	# Dans le cas d'un RAC, le nom de l'instance n'est pas le même que celui
	# de la base : ORACLE_SID != db_name.
	exit_if_param_undef	db "$str_usage"

	info "Stop database :"
	exec_cmd "srvctl stop database -db $db"
	LN

	wait_if_high_load_average

	# Si utlisation de srvctl les instances sont démarrées sur tous les noeuds,
	# il faudrait utiliser 'start instance' plutôt uque 'start database'.
	sqlplus_cmd "$(set_sql_cmd "startup mount")"
	LN

	wait_if_high_load_average

	info "Enable archivelog :"
	sqlplus_cmd "$(sqlcmd_enable_archivelog_with_GI)"
	LN

	wait_if_high_load_average

	# La base est stoppée après l'activation des archivelogs, util pour les RAC.
	info "Start database :"
	exec_cmd "srvctl start database -db $db"
	LN
}

if command_exists olsnodes
then
	enable_archivelog_with_GI
else
	enable_archivelog_without_GI
fi
