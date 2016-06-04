#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

function stop_db_without_srvctl
{
fake_exec_cmd "sqlplus sys/$oracle_password as sysdba"
sqlplus sys/$oracle_password as sysdba<<EOS
archive log list;
shutdown immediate
startup mount
alter database archivelog;
alter database open;
shutdown immediate
startup
archive log list;
EOS
}

function stop_db
{
exec_cmd "srvctl stop database -db $ORACLE_SID"
fake_exec_cmd "sqlplus sys/$oracle_password as sysdba"
sqlplus sys/$oracle_password as sysdba<<EOS
startup mount
alter database archivelog;
alter database open;
shutdown immediate
EOS
exec_cmd "srvctl start database -db $ORACLE_SID"
}

test_if_cmd_exists srvctl
[ $? -ne 0 ] && stop_db_without_srvctl || stop_db
