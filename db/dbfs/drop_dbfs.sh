#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset db=undef
typeset pdb=undef
typeset	drop_user=yes

typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
	[-skip_drop_user]	Utile si le pdb va être supprimé.
"

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

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-skip_drop_user)
			drop_user=no
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

exit_if_ORACLE_SID_not_defined

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

typeset	-r	dbfs_cfg_file=~/${pdb}_dbfs.cfg

if [ ! -f $dbfs_cfg_file ]
then
	echo "Error file $dbfs_cfg_file not exists."
	exit 1
fi

. $dbfs_cfg_file

if [ "$(dataguard_config_available)" == yes ]
then
	typeset	-r role=$(read_database_role $db)
else
	typeset	-r role=primary
fi

line_separator
exec_cmd -c  "crsctl stop res pdb.${pdb}.dbfs -f"
LN
exec_cmd -c  "crsctl delete res pdb.${pdb}.dbfs -f"
LN

if [[ $drop_user == yes && $role == primary ]]
then
	sqlplus -s $dbfs_user/$dbfs_password@$service<<-EOSQL
	prompt drop filesystem DBFS $dbfs_name
	@?/rdbms/admin/dbfs_drop_filesystem.sql $dbfs_name
	EOSQL
	LN

	sqlplus -s sys/Oracle12@$service as sysdba<<-EOSQL
	prompt drop user $dbfs_user
	drop user $dbfs_user cascade;
	prompt drop tbs $dbfs_tbs
	drop tablespace $dbfs_tbs including contents and datafiles;
	EOSQL
	LN
fi

line_separator
exec_cmd "~/plescripts/db/wallet/delete_credential.sh -tnsalias=$service"
LN

execute_on_all_nodes "rm -f $dbfs_cfg_file"
LN

execute_on_all_nodes "sudo -iu grid rm /home/grid/mount-dbfs-$pdb"
LN

exec_cmd "su - root -c 'plescripts/db/dbfs/root_clean_mount_point.sh	\
									-pdb=$pdb -service=$service'"
LN
