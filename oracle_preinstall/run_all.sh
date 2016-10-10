#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r db_type=$1

cd ~/plescripts/oracle_preinstall

exec_cmd "./01_create_oracle_users.sh -release=$oracle_release -db_type=$db_type"
LN

exec_cmd "./02_install_some_rpms.sh"
LN

if [ $db_type != single_fs ]
then
	exec_cmd "./03_install_oracleasm.sh"
	LN
fi

exec_cmd "./04_apply_os_prerequis.sh -db_type=$db_type"
LN

exit
