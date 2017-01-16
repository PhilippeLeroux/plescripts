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
\t-db=name
\t-pdb=name
\t[-drop_wallet=no] yes|no
"

typeset db=undef
typeset pdb=undef
typeset drop_wallet=no

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

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_param_invalid drop_wallet "yes no" "$str_usage"

typeset	-r	dbfs_cfg_file=~/${pdb}_dbfs.cfg

if [ ! -f $dbfs_cfg_file ]
then
	echo "Error file $dbfs_cfg_file not exists."
	exit 1
fi

. $dbfs_cfg_file

if dataguard_config_available
then
	typeset	-r role=$(read_database_role $db)
else
	typeset	-r role=primary
fi

line_separator
execute_on_all_nodes_v2 -c "fusermount -u /mnt/$pdb"
LN

if [ $role == primary ]
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
info "Remove credential for service $service"
cat<<EOS>/tmp/deletecred.sh
#!/bin/bash
echo mkstore -wrl $ORACLE_HOME/oracle/wallet -deleteCredential $service
mkstore -wrl $ORACLE_HOME/oracle/wallet -deleteCredential $service<<EOP
$oracle_password
EOP
EOS
chmod u+x /tmp/deletecred.sh

exec_cmd /tmp/deletecred.sh
LN

if [ $gi_count_nodes -ne 1 ]
then
	exec_cmd touch $ORACLE_HOME/oracle/wallet/is_cfs
	ssh ${gi_node_list[0]} test -f $ORACLE_HOME/oracle/wallet/is_cfs
	if [ $? -ne 0 ]
	then # ce n'est pas un CFS
		for node in ${gi_node_list[*]}
		do
			exec_cmd scp /tmp/deletecred.sh ${node}:/tmp/deletecred.sh
			exec_cmd "ssh ${node} '. .bash_profile; /tmp/deletecred.sh'"
			LN
		done
	fi
	exec_cmd rm $ORACLE_HOME/oracle/wallet/is_cfs
	LN
fi

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
fi

info "Done."
