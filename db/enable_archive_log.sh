#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

info "Running : $ME $*"

typeset -r	SQL_PROMPT="prompt SQL>"

#	$@	liste des mots constituant l'instruction sql à exécuter.
function exec_sql
{
    typeset -r sql_cmd="$@"
    [ "${sql_cmd:${#sql_cmd}-1}" == ";" ] && typeset -r eoc=";"
    echo "$SQL_PROMPT $sql_cmd$eoc"
    echo "$sql_cmd"
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
	typeset -r cmds="$(make_sql_cmds_without_srvctl)"
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
	typeset -r cmds="$(make_sql_cmds)"

	if [ ! -v ORACLE_DB ]
	then
		error "ORACLE_DB not defined."
		exit 1
	fi

	exec_cmd "srvctl stop database -db $ORACLE_DB"
	fake_exec_cmd "sqlplus sys/$oracle_password as sysdba"
	printf "set echo off\nset timin on\n$cmds\n" | sqlplus -s sys/$oracle_password as sysdba
	exec_cmd "srvctl start database -db $ORACLE_DB"
}

test_if_cmd_exists olsnodes
[ $? -ne 0 ] && enable_archivelog_without_srvctl || enable_archivelog
