#!/bin/bash

if [ ! -f account.txt ]
then
	echo "Error file account.txt not exists."
	exit 1
fi

. account.txt

sqlplus -s $dbfs_user/$dbfs_password@$service<<EOSQL
prompt drop filesystem DBFS staging_area
@?/rdbms/admin/dbfs_drop_filesystem.sql staging_area
EOSQL

echo

sqlplus -s sys/Oracle12@$service as sysdba<<EOSQL
prompt drop user $dbfs_user
drop user $dbfs_user cascade;
prompt drop tbs $dbfs_tbs
drop tablespace $dbfs_tbs including contents and datafiles;
EOSQL

echo
