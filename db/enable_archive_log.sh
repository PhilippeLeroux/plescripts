#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage :
$ME
	[-db=name] Database name, mandatory if Grid installed.
"
script_banner $ME $*

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

	set_sql_cmd "shutdown immediate"

	set_sql_cmd "startup"
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

	#	Je ne fais plus de startup mount avec sqlplus, car si les schémas sont
	#	créés l'alias sur le spfile n'est pas créé et la command échoue en
	#	disant que le spfile n'existe pas.
	info "Start instance $ORACLE_SID"
	exec_cmd srvctl start instance	-db $db					\
									-instance $ORACLE_SID	\
									-startoption mount

	info "Enable archivelog :"
	sqlplus_cmd "$(sqlcmd_enable_archivelog_with_GI)"
	LN

	info "Start database :"
	exec_cmd "srvctl start database -db $db"
	LN
}

if test_if_cmd_exists olsnodes
then
	enable_archivelog_with_GI
else
	enable_archivelog_without_GI
fi
