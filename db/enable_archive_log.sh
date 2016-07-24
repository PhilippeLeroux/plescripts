#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r	SQL_PROMPT="prompt SQL>"

function exec_sql
{
	echo "$SQL_PROMPT $@"
	echo "$@"
	echo "prompt"
}

function make_sql_cmds_without_srvctl
{
	cat <<EOS
$(exec_sql archive log list)

$(exec_sql shutdown immediate)

$(exec_sql startup mount)

$(exec_sql alter database archivelog\;)

$(exec_sql alter database open\;)

$(exec_sql shutdown immediate)

$(exec_sql startup)

$(exec_sql archive log list)
EOS
}

function enable_archivelog_without_srvctl
{
	typeset -r cmds=$(printf "$(make_sql_cmds_without_srvctl)\n")
	fake_exec_cmd "sqlplus sys/$oracle_password as sysdba"
	printf "set echo off\nset timin on\n$cmds\n" | sqlplus -s sys/$oracle_password as sysdba
	LN
}

function make_sql_cmds
{
	cat <<EOS
$(exec_sql startup mount)

$(exec_sql alter database archivelog\;)

$(exec_sql alter database open\;)

$(exec_sql archive log list)

$(exec_sql shutdown immediate)
EOS
}

function enable_archivelog
{
	typeset -r cmds=$(printf "$(make_sql_cmds)\n")

	if [ ! -v ORACLE_DB ]
	then
		error "Définir la variable ORACLE_DB avec le nom de la base."
		exit 1
	fi

	exec_cmd "srvctl stop database -db $ORACLE_DB"
	fake_exec_cmd "sqlplus sys/$oracle_password as sysdba"
	printf "set echo off\nset timin on\n$cmds\n" | sqlplus -s sys/$oracle_password as sysdba
	exec_cmd "srvctl start database -db $ORACLE_DB"
}

test_if_cmd_exists olsnodes
[ $? -ne 0 ] && enable_archivelog_without_srvctl || enable_archivelog
