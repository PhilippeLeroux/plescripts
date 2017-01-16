#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME
\t-pdb=name
\t[-drop_wallet=yes]\tyes|no
"

typeset pdb=undef
typeset drop_wallet=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-drop_wallet=*)
			drop_wallet=${1##*=}
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

exit_if_param_undef pdb	"$str_usage"

exit_if_param_invalid drop_wallet "yes no" "$str_usage"

typeset	-r	dbfs_cfg_file=~/${pdb}_dbfs.cfg

if [ ! -f $dbfs_cfg_file ]
then
	echo "Error file $dbfs_cfg_file not exists."
	exit 1
fi

. $dbfs_cfg_file

line_separator
execute_on_all_nodes_v2 -c "fusermount -u /mnt/$pdb"
LN

sqlplus -s $dbfs_user/$dbfs_password@$service<<EOSQL
prompt drop filesystem DBFS $dbfs_name
@?/rdbms/admin/dbfs_drop_filesystem.sql $dbfs_name
EOSQL
LN

sqlplus -s sys/Oracle12@$service as sysdba<<EOSQL
prompt drop user $dbfs_user
drop user $dbfs_user cascade;
prompt drop tbs $dbfs_tbs
drop tablespace $dbfs_tbs including contents and datafiles;
EOSQL
LN

if [ $drop_wallet == yes ]
then
	line_separator
	execute_on_all_nodes_v2 'sed -i "/WALLET_LOCATION/d" $TNS_ADMIN/sqlnet.ora'
	execute_on_all_nodes_v2 'sed -i "/SQLNET.WALLET_OVERRIDE/d" $TNS_ADMIN/sqlnet.ora'
	LN

	execute_on_all_nodes_v2 "rm -f $dbfs_cfg_file"
	LN

	execute_on_all_nodes_v2 "rm -rf $ORACLE_HOME/oracle/wallet"
	LN
else
	fake_exec_cmd mkstore -wrl $ORACLE_HOME/oracle/wallet -deleteCredential $service
	mkstore -wrl $ORACLE_HOME/oracle/wallet -deleteCredential $service<<-EOP
	$oracle_password
	EOP
	LN
fi

info "Done."
