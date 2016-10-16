#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
EXEC_CMD_ACTION=EXEC

#	============================================================================
#	Fonctions fabriquant les commandes sql.

function sqlcmd_restart_to_mount_state
{
	set_sql_cmd "shutdown immediate"

	set_sql_cmd "startup mount"
}

function sqlcmd_enable_archivelog
{
	set_sql_cmd "alter database archivelog;"

	set_sql_cmd "alter database open;"

	set_sql_cmd "archive log list;"
}

function sqlcmd_enable_archivelog_full_sqlplus
{
	sqlcmd_restart_to_mount_state

	sqlcmd_enable_archivelog

	set_sql_cmd "shutdown immediate"

	set_sql_cmd "startup"
}

function sqlcmd_enable_archivelog_GI_present
{
	set_sql_cmd "startup mount"

	sqlcmd_enable_archivelog

	set_sql_cmd "shutdown immediate"
}

#	============================================================================
#	MAIN

#	Active les archivelogs avec la commande sqlplus.
function enable_archivelog_with_sqlplus
{
	sqlplus_cmd "$(sqlcmd_enable_archivelog_full_sqlplus)"
	LN
}

#	Active les archivelogs quand le Grid Infra est présent (RAC possible).
function enable_archivelog_GI_present
{
	if [ ! -v ORACLE_DB ]
	then
		error "ORACLE_DB not defined."
		exit 1
	fi

	info "Stop database :"
	exec_cmd "srvctl stop database -db $ORACLE_DB"
	LN

	info "Enable archivelog :"
	sqlplus_cmd "$(sqlcmd_enable_archivelog_GI_present)"
	LN

	info "Start database :"
	exec_cmd "srvctl start database -db $ORACLE_DB"
	LN
}

test_if_cmd_exists olsnodes
[ $? -ne 0 ] && enable_archivelog_with_sqlplus || enable_archivelog_GI_present
