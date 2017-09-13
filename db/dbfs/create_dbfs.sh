#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset db=undef
typeset pdb=undef
typeset service=auto
typeset account_name=dbfsadm
typeset	account_password=dbfs
typeset wallet=$(enable_wallet $(read_orcl_release))

typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
	[-service=$service]
	[-account_name=$account_name]
	[-account_password=$account_password]
	[-wallet=$wallet]	yes|no : no ==> password file.

For dataguard must be executed first on the primary database.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-service=*)
			service=${1##*=}
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

exit_if_param_undef db					"$str_usage"
exit_if_param_undef pdb					"$str_usage"
exit_if_param_undef account_name		"$str_usage"
exit_if_param_undef account_password	"$str_usage"

exit_if_param_invalid wallet "yes no"	"$str_usage"

ple_enable_log -params $PARAMS

[ "$service" == auto ] && service=$(mk_oci_service $pdb) || true

typeset	-r	dbfs_tbs=${account_name}_tbs
typeset	-r	dbfs_name=staging_area
typeset -r	pass_file=~/${pdb}_pass
account_name=$(to_upper $account_name)

function create_user_dbfs
{
	function sql_create_user_dbfs
	{
		set_sql_cmd "set ver off"
		set_sql_cmd "set feed on"
		set_sql_cmd "@create_user_dbfs.sql $dbfs_tbs $account_name $account_password"
	}

	line_separator
	sqlplus_cmd_with	"sys/$oracle_password@${service} as sysdba"	\
						"$(sql_create_user_dbfs)"
	LN
}

function create_dbfs
{
	function sql_create_dbfs
	{
		set_sql_cmd "@?/rdbms/admin/dbfs_create_filesystem.sql	$dbfs_tbs $dbfs_name nocompress nodeduplicate noencrypt partition"
	}

	line_separator
	sqlplus_cmd_with	"$account_name/$account_password@${service}"	\
						"$(sql_create_dbfs)"
	LN
}

function create_file_dbfs_config
{
	line_separator
	typeset	-r	dbfs_cfg_file=~/${pdb}_dbfs.cfg
	info "Save configuration to $dbfs_cfg_file"
	exec_cmd "echo 'service=$service' > $dbfs_cfg_file"
	exec_cmd "echo 'dbfs_user=$account_name' >> $dbfs_cfg_file"
	exec_cmd "echo 'dbfs_password=$account_password' >> $dbfs_cfg_file"
	exec_cmd "echo 'dbfs_tbs=$dbfs_tbs' >> $dbfs_cfg_file"
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

function create_password_file
{
	line_separator
	info "Save $account_name to $pass_file file."
	exec_cmd "echo '$account_password' > $pass_file"
	LN
	if [ $gi_count_nodes -gt 1 ]
	then
		info "Copy $pass_file to nodes : $gi_node_list"
		for node in ${gi_node_list[*]}
		do
			exec_cmd "scp $pass_file $node:$pass_file"
		done
		LN
	fi
}

#	Copie dans le dbfs les fichiers du répertoire courant pour valider le bon
#	fonctionnement.
function load_data_tests
{
	line_separator
	info "Tests :"
	if [ $wallet == yes ]
	then
		typeset	-r connect_string=/@$service
	else
		typeset	-r connect_string=$account_name@$service
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
	info "DB          : $db"
	info "PDB         : $pdb"
	info "Service     : $service"
	info "DBFS user   : $account_name/$account_password"
	if [ $wallet == yes ]
	then
		info "Wallet used."
	else
		info "Use password file."
	fi
	LN
}

resume

typeset -r dg_cfg_available="$(dataguard_config_available)"
if [ "$dg_cfg_available" == yes ]
then
	if [[  $gi_count_nodes -gt 1 ]]
	then
		error "RAC + Dataguard not supported."
		exit 1
	fi
	typeset -r role=$(read_database_role $db)
else
	typeset -r role=primary
fi

if [ $role == primary ]
then
	exit_if_service_not_running $db $service

	create_user_dbfs

	create_dbfs
else
	function read_user
	{
		typeset -r stby_service=$(mk_oci_stby_service $pdb)
		sqlplus -s sys/${oracle_password}@${stby_service} as sysdba<<-EOSQL | tail -1
		set feed off  head off
		select username from dba_users where username='$account_name';
		EOSQL
	}

	exit_if_service_not_exists $db $service

	if [ "$(read_user)" != $account_name ]
	then
		error "Script not executed on primary database, user $account_name not exists."
		LN
		exit 1
	fi
fi

create_file_dbfs_config

if [ $wallet == yes ]
then
	exec_cmd ~/plescripts/db/wallet/create_credential.sh	\
									-nolog					\
									-tnsalias=$service		\
									-user=$account_name		\
									-password=$account_password
	LN
else
	create_password_file
fi

[ $role == primary ] && load_data_tests || true

line_separator
confirm_or_exit -reply_list=CR "root password for $(hostname -s) will be asked. Press enter to continue"
add_dynamic_cmd_param "\"plescripts/db/dbfs/configure_fuse_and_dbfs_mount_point.sh"
add_dynamic_cmd_param "-db=$db -pdb=$pdb -nolog\""
exec_dynamic_cmd "su - root -c"
LN

if test_if_cmd_exists crsctl
then
	line_separator
	add_dynamic_cmd_param "plescripts/db/dbfs/create_crs_resource_for_dbfs.sh"
	add_dynamic_cmd_param "-db=$db -pdb=$pdb -service=$service -nolog"
	exec_dynamic_cmd "sudo -iu grid"
	LN
else
	line_separator
	warning "Disconnect and connect oracle and execute :"
	warning "$ mount /mnt/$pdb"
	LN
fi

if [[ $dg_cfg_available == yes && $role == primary ]]
then
	typeset -a physical_list
	typeset -a stby_server_list
	load_stby_database
	for (( i=0; i<${#physical_list[*]}; ++i ))
	do
		warning "On server ${stby_server_list[i]}"
		info "$ ssh oracle@${stby_server_list[i]}"
		info "$ cd ~/plescripts/db/dbfs"
		info "$ $ME -db=${physical_list[i]} -pdb=$pdb -service=$service"
		LN
	done
fi
