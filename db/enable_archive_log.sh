#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

function stop_db_without_srvctl
{
fake_exec_cmd "sqlplus sys/$oracle_password as sysdba"
sqlplus sys/$oracle_password as sysdba<<EOS
set echo off
prompt archive log list;
archive log list;

prompt shutdown immediate
shutdown immediate

prompt startup mount
startup mount

prompt alter database archivelog;
alter database archivelog;

prompt alter database open;
alter database open;

prompt shutdown immediate
shutdown immediate

prompt startup
startup

prompt archive log list;
archive log list;
EOS
}

function stop_db
{
exec_cmd "srvctl stop database -db $ORACLE_SID"
fake_exec_cmd "sqlplus sys/$oracle_password as sysdba"
sqlplus sys/$oracle_password as sysdba<<EOS
set echo off

prompt startup mount
startup mount

prompt alter database archivelog;
alter database archivelog;

prompt alter database open;
alter database open;

prompt alter database archivelog;
alter database archivelog;

prompt shutdown immediate
shutdown immediate
EOS
exec_cmd "srvctl start database -db $ORACLE_SID"
}

test_if_cmd_exists olsnodes
[ $? -ne 0 ] && stop_db_without_srvctl || stop_db
