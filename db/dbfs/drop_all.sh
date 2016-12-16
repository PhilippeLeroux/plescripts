#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME -pdb_name=name"

typeset pdb_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-pdb_name=*)
			pdb_name=${1##*=}
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

must_be_user oracle

typeset	-r	dbfs_info=~/${pdb_name}_infra

if [ ! -f $dbfs_info ]
then
	echo "Error file $dbfs_info not exists."
	exit 1
fi

. $dbfs_info

sqlplus -s $dbfs_user/$dbfs_password@$service<<EOSQL
prompt drop filesystem DBFS $dbfs_name
@?/rdbms/admin/dbfs_drop_filesystem.sql $dbfs_name
EOSQL

echo

sqlplus -s sys/Oracle12@$service as sysdba<<EOSQL
prompt drop user $dbfs_user
drop user $dbfs_user cascade;
prompt drop tbs $dbfs_tbs
drop tablespace $dbfs_tbs including contents and datafiles;
EOSQL

echo
