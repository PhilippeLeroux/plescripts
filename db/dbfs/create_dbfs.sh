#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME
	-pdb_name=name
	-account_name=name
	-account_password=password
	[-db_name=name]
	[-service_name=name]
	[-load_data]	Charge dans le FS le contenu du répertoire courant.
"

script_banner $ME $*

typeset db_name=auto
typeset pdb_name=undef
typeset service_name=auto
typeset account_name=undef
typeset	account_password=undef

typeset	load_data=no

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

		-db_name=*)
			db_name=${1##*=}
			shift
			;;

		-service_name=*)
			pdb_name=${1##*=}
			shift
			;;

		-account_name=*)
			account_name=${1##*=}
			shift
			;;

		-account_password=*)
			account_password=${1##*=}
			shift
			;;

		-load_data)
			load_data=yes
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

exit_if_param_undef pdb_name			"$str_usage"
exit_if_param_undef account_name		"$str_usage"
exit_if_param_undef account_password	"$str_usage"

must_be_user oracle

[ "$db_name" == auto ] && db_name=$(extract_db_name_from $pdb_name)
[ "$service_name" == auto ] && service_name=$(make_oci_service_name_for $pdb_name)

typeset	-r	account_tbs=${account_name}_tbs
typeset	-r	dbfs_name=staging_area

exit_if_service_not_running $db_name $pdb_name $service_name

fake_exec_cmd sqlplus -s sys/$oracle_password@${service_name} as sysdba
sqlplus -s sys/$oracle_password@${service_name} as sysdba<<EOSQL
set ver off
set echo on
set feed on
@create_user_dbfs.sql $account_tbs $account_name $account_password
EOSQL
LN

fake_exec_cmd sqlplus -s $account_name/$account_password@${service_name}
sqlplus -s $account_name/$account_password@${service_name}<<EOSQL
prompt create filesystem $dbfs_name on tablespace $account_tbs
@?/rdbms/admin/dbfs_create_filesystem.sql $account_tbs $dbfs_name
EOSQL
LN

typeset	-r	dbfs_info=~/${pdb_name}_infra
info "Save account info to $dbfs_info"
exec_cmd "echo 'service=$service_name' > $dbfs_info"
exec_cmd "echo 'dbfs_user=$account_name' >> $dbfs_info"
exec_cmd "echo 'dbfs_password=$account_password' >> $dbfs_info"
exec_cmd "echo 'dbfs_tbs=$account_tbs' >> $dbfs_info"
exec_cmd "echo 'dbfs_name=$dbfs_name' >> $dbfs_info"
LN

info "Save $account_name to ~/${pdb_name}_pass file."
exec_cmd "echo '$account_password' > ~/${pdb_name}_pass"
LN

if [ $load_data == yes ]
then
	line_separator
	info "Tests :"
	typeset	-r connect_string=$account_name@$service_name

	exec_cmd "dbfs_client $connect_string --command ls dbfs:/$dbfs_name/ < ~/${pdb_name}_pass"
	LN

	exec_cmd "dbfs_client $connect_string --command cp -pR ./* dbfs:/$dbfs_name/ < ~/${pdb_name}_pass"
	LN

	exec_cmd "dbfs_client $connect_string --command ls dbfs:/$dbfs_name/ < ~/${pdb_name}_pass"
	LN
fi
