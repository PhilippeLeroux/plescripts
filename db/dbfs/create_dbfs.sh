#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

typeset db_name=auto
typeset pdb_name=undef
typeset service_name=auto
typeset account_name=dbfsadm
typeset	account_password=dbfs
typeset	wallet=yes
typeset	wallet_path=$ORACLE_HOME/oracle/wallet

typeset	load_data=no

typeset -r str_usage=\
"Usage : $ME
	-pdb_name=name
	[-account_name=$account_name]
	[-account_password=$account_password]
	[-db_name=name]
	[-service_name=name]
	[-wallet_path=$wallet_path]

Debug flags :
	[-wallet=yes]	yes|no : with 'no', uses password file.
	[-load_data]	Charge dans le FS le contenu du répertoire courant.
"

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

		-wallet_path=*)
			wallet_path=${1##*=}
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

		-wallet=*)
			wallet=${1##*=}
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

exit_if_param_invalid wallet "yes no"	"$str_usage"

must_be_user oracle

[ "$db_name" == auto ] && db_name=$(extract_db_name_from $pdb_name)
[ "$service_name" == auto ] && service_name=$(make_oci_service_name_for $pdb_name)

typeset	-r	account_tbs=${account_name}_tbs
typeset	-r	dbfs_name=staging_area
typeset -r	pass_file=~/${pdb_name}_pass

function create_user_dbfs
{
	line_separator
	fake_exec_cmd sqlplus -s sys/$oracle_password@${service_name} as sysdba
	sqlplus -s sys/$oracle_password@${service_name} as sysdba<<-EOSQL
	set ver off
	set echo on
	set feed on
	@create_user_dbfs.sql $account_tbs $account_name $account_password
	EOSQL
	LN
}

function create_dbfs
{
	line_separator
	fake_exec_cmd sqlplus -s $account_name/$account_password@${service_name}
	sqlplus -s $account_name/$account_password@${service_name}<<-EOSQL
	prompt create filesystem $dbfs_name on tablespace $account_tbs
	@?/rdbms/admin/dbfs_create_filesystem.sql $account_tbs $dbfs_name
	EOSQL
	LN
}

function create_file_dbfs_config
{
	line_separator
	typeset	-r	dbfs_cfg_file=~/${pdb_name}_dbfs.cfg
	info "Save configuration to $dbfs_cfg_file"
	exec_cmd "echo 'service=$service_name' > $dbfs_cfg_file"
	exec_cmd "echo 'dbfs_user=$account_name' >> $dbfs_cfg_file"
	exec_cmd "echo 'dbfs_password=$account_password' >> $dbfs_cfg_file"
	exec_cmd "echo 'dbfs_tbs=$account_tbs' >> $dbfs_cfg_file"
	exec_cmd "echo 'dbfs_name=$dbfs_name' >> $dbfs_cfg_file"
	exec_cmd "echo 'wallet=$wallet' >> $dbfs_cfg_file"
	LN
	if [ $gi_count_nodes -gt 1 ]
	then
		info "Copy $dbfs_cfg_file to nodes : $gi_node_list"
		for node in $gi_node_list
		do
			exec_cmd "scp $dbfs_cfg_file $node:$dbfs_cfg_file"
		done
		LN
	fi
}

function create_wallet_store
{
	line_separator
	if [ ! -d $wallet_path ]
	then
		exec_cmd ~/plescripts/db/wallet/create_wallet.sh -wallet_path=$wallet_path
	else
		info "$wallet_path exists."
	fi
	LN
}

function add_dbfs_user_to_wallet_store
{
	line_separator
	info "Add $account_name to wallet"

	fake_exec_cmd mkstore -wrl $wallet_path	\
				-createCredential $service_name $account_name $account_password

	mkstore -wrl $wallet_path	\
			-createCredential $service_name $account_name $account_password<<-EOP
	$oracle_password
	EOP
	LN
}

#	Si $wallet_path n'est pas sur un Cluster FS, il est copié sur tous les noeuds
#	du cluster.
function copy_store_if_not_cfs
{
	for node in $gi_node_list
	do
		line_separator
		info "Test CFS"
		exec_cmd -c ssh $node test -d $wallet_path
		if [ $? -ne 0 ]
		then # Ce n'est pas sur un CFS : copie
			info "copy store to $node"
			exec_cmd scp -pr $wallet_path ${node}:${wallet_path%/*}
			LN
		fi
	done
}

function create_password_file
{
	line_separator
	info "Save $account_name to $pass_file file."
	exec_cmd "echo '$account_password' > $pass_file"
	LN
	if [ $gi_count_nodes -gt 1 ]
	then
		info "Copy $pass_file to nodes : $gi_node_list"
		for node in $gi_node_list
		do
			exec_cmd "scp $pass_file $node:$pass_file"
		done
		LN
	fi
}

function load_data
{
	line_separator
	info "Tests :"
	if [ $wallet == yes ]
	then
		typeset	-r connect_string=/@$service_name
	else
		typeset	-r connect_string=$account_name@$service_name
	fi

	ls_dbfs="dbfs_client $connect_string --command ls dbfs:/$dbfs_name/"
	cp_dbfs="dbfs_client $connect_string --command cp -pR ./* dbfs:/$dbfs_name/"

	if [ $wallet != yes ]
	then
		ls_dbfs="$ls_dbfs < $pass_file"
		cp_dbfs="$cp_dbfs < $pass_file"
	fi

	exec_cmd "$ls_dbfs"
	LN

	exec_cmd -c "$cp_dbfs"
	LN

	exec_cmd "$ls_dbfs"
	LN
}

function resume
{
	line_separator
	info "Resume"
	info "DB          : $db_name"
	info "PDB         : $pdb_name"
	info "Service     : $service_name"
	info "DBFS user   : $account_name/$account_password"
	if [ $wallet == yes ]
	then
		info "Wallet path : $wallet_path"
	else
		info "Use password file : debug mode !"
	fi
	[ $load_data == yes ] && info "Load data for tests." || true
	LN
}

resume

exit_if_service_not_running $db_name $pdb_name $service_name

create_user_dbfs

create_dbfs

create_file_dbfs_config

if [ $wallet == yes ]
then
	create_wallet_store
	add_dbfs_user_to_wallet_store
	copy_store_if_not_cfs
else
	create_password_file
fi

[ $load_data == yes ] && load_data || true

exec_cmd crsctl stat res -t
LN

info "With user root execute :"
info "cd plescripts/db/dbfs/"
info "./configure_fuse_and_dbfs_mount_point.sh -service_name=$service_name"
LN
