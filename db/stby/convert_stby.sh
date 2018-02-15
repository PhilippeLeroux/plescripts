#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage :
$ME
	-db=name               Database name.
	-role=primary|physical Database role.

Note -role=physical convert database to normal database.
"

typeset db=undef
typeset role=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_upper ${1##*=})
			shift
			;;

		-role=*)
			role=${1##*=}
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

exit_if_param_undef db		"$str_usage"

exit_if_param_invalid role "primary physical" "$str_usage"

function sqlcmd_reset_dataguard_cfg
{
	set_sql_cmd "alter system reset standby_file_management scope=spfile sid='*';"

	set_sql_cmd "alter system reset log_archive_config scope=spfile sid='*';"

	set_sql_cmd "alter system reset fal_server scope=spfile sid='*';"

	set_sql_cmd "alter system reset log_archive_dest_1 scope=spfile sid='*';"

	set_sql_cmd "alter system reset log_archive_dest_2 scope=spfile sid='*';"

	set_sql_cmd "alter system reset log_archive_dest_state_2 scope=spfile sid='*';"

	set_sql_cmd "alter system reset remote_login_passwordfile scope=spfile sid='*';"

	# Les 2 paramètres ne sont pas positionné, mais me sert de mémo pour ailleurs.
	set_sql_cmd "alter system reset db_file_name_convert scope=spfile sid='*';"

	set_sql_cmd "alter system reset log_file_name_convert scope=spfile sid='*';"
	#	--

	set_sql_cmd "alter system reset dg_broker_config_file1 scope=spfile sid='*';"

	set_sql_cmd "alter system reset dg_broker_config_file2 scope=spfile sid='*';"

	set_sql_cmd "alter system reset dg_broker_start scope=spfile sid='*';"

	set_sql_cmd "alter database no force logging;"
}

function remove_broker_cfg
{
	line_separator
	fake_exec_cmd dgmgrl
	dgmgrl -silent -echo<<-EOS  | tee -a $PLELIB_LOG_FILE
	connect sys/$oracle_password
	disable configuration;
	remove configuration;
	EOS
	LN

	line_separator
	if [ $crs_used == yes ]
	then
		exec_cmd -c sudo -iu grid "asmcmd rm -f DATA/$db/dr1db_*.dat"
		LN
		exec_cmd -c sudo -iu grid "asmcmd rm -f FRA/$db/dr2db_*.dat"
		LN
	else
		typeset	-r	data_cfg=$(orcl_parameter_value db_create_file_dest)
		typeset	-r	fra_cfg=$(orcl_parameter_value db_recovery_file_dest)
		exec_cmd "rm -f $data_cfg/$db/dr1db_*.dat  $fra_cfg/$db/dr2db_*.dat"
		LN
	fi
}

# Remarque : avec un dataguard passif le remove de la standby du broker échoue,
# mais fonctionne correctement avec un dataguard actif...
function remove_database_from_broker
{
	line_separator
	fake_exec_cmd dgmgrl
	dgmgrl -silent -echo<<-EOS | tee -a $PLELIB_LOG_FILE
	connect sys/$oracle_password
	remove database $db;
	EOS
	LN

	if [ $crs_used == yes ]
	then
		exec_cmd -c sudo -iu grid "asmcmd rm -f DATA/$db/dr1db_*.dat"
		exec_cmd -c sudo -iu grid "asmcmd rm -f FRA/$db/dr2db_*.dat"
		LN
	else
		typeset	-r	data_cfg=$(orcl_parameter_value db_create_file_dest)
		typeset	-r	fra_cfg=$(orcl_parameter_value db_recovery_file_dest)
		exec_cmd "rm -f $data_cfg/$db/dr1db_*.dat  $fra_cfg/$db/dr2db_*.dat"
		LN
	fi
}

function convert_physical_to_primary
{
	function sql_convert_to_primary
	{
		set_sql_cmd "recover managed standby database finish;"
		set_sql_cmd "alter database commit to switchover to primary with session shutdown;"
	}

	if [ $start_option != mount ]
	then
		info "Restart database to mount state."
		LN

		if [ $crs_used == yes ]
		then
			exec_cmd srvctl stop database -db $db
			exec_cmd srvctl start database -db $db -startoption mount
			LN
		else
			function sql_mount_db
			{
				set_sql_cmd "shu immediate;"
				set_sql_cmd "startup mount;"
			}
			sqlplus_cmd "$(sql_mount_db)"
			LN
		fi
	fi

	info "Convert Physical database to Primary database."
	LN
	sqlplus_cmd "$(sql_convert_to_primary)"
	ret=$?
	LN
	[ $ret -ne 0 ] && exit 1 || true

	timing 20 "Wait switchover to primary"
	LN

	if [ $crs_used == yes ]
	then
		exec_cmd srvctl stop database -db $db
		exec_cmd srvctl start database -db $db
		LN
	else
		function sql_bounce_db
		{
			set_sql_cmd "shu immediate;"
			set_sql_cmd "startup;"
		}
		sqlplus_cmd "$(sql_bounce_db)"
		LN
	fi
}

function remove_SRLs
{
	line_separator
	info "Drop Standby redo log"
	sqlplus_cmd "@drop_standby_redolog.sql"
	LN
}

function drop_all_services
{
	line_separator
	if [ $crs_used == yes ]
	then
		exec_cmd -c ~/plescripts/db/drop_all_services.sh -db=$db
		LN
	else
		exec_cmd -c ~/plescripts/db/fsdb_drop_all_stby_services.sh -db=$db
		LN
	fi
}

function create_services_for_single_db
{
	case $start_option in
		mount)
			line_separator
			info "Open database RW."
			sqlplus_cmd "$(set_sql_cmd "alter database open;")"
			LN

			info "Open all PDB RW"
			sqlplus_cmd "$(set_sql_cmd "alter pluggable database all open;")"
			LN

			info "PDBs :"
			sqlplus_cmd "$(set_sql_cmd @lspdbs)"
			LN
			;;
	esac

	while read pdb
	do
		[ x"$pdb" == x ] && continue || true

		line_separator
		exec_cmd "~/plescripts/db/create_srv_for_single_db.sh -db=$db -pdb=$pdb"
		LN
	done<<<"$(get_rw_pdbs $ORACLE_SID)"
}

ple_enable_log -params $PARAMS

exit_if_database_not_exists $db

load_oraenv_for $db

if command_exists crsctl
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

typeset -r role_cfg=$(read_database_role $(to_lower $db))

info "$db role=$role, role read from configuration : ${role_cfg:-undef}"
LN

if [[ x"$role_cfg" != x && "$role" != "$role_cfg" ]]
then
	error "role $role invalid ?"
	LN
	exit 1
fi

if [ $role == physical ]
then
	if dgmgrl -silent sys/$oracle_password "show database $db"|grep -qE "Real Time Query: *OFF"
	then
		typeset	-r start_option=mount
		info "Passive Dataguard"
		LN
	else
		typeset	-r start_option=ro
		info "Active Dataguard"
		LN
	fi

	convert_physical_to_primary

	remove_database_from_broker
else
	typeset	-r start_option=rw
	remove_broker_cfg
fi

remove_SRLs

drop_all_services

if [[ $role == physical ]]
then
	if [ $crs_used == yes ]
	then
		line_separator
		exec_cmd srvctl modify database -db $db -startoption open
		exec_cmd srvctl modify database -db $db -role primary
		LN
	fi
fi

create_services_for_single_db

line_separator
info "Reset dataguard configuration."
sqlplus_cmd "$(sqlcmd_reset_dataguard_cfg)"
LN

line_separator
info "Optionnal, not necessary on a production server."
exec_cmd "~/plescripts/db/bounce_db.sh"
LN

exec_cmd -c "rm $ORACLE_BASE/diag/rdbms/$(to_lower $db)/$db/trace/drc$db.log"
LN

line_separator
exec_cmd rman target=sys/$oracle_password<<<"configure archivelog deletion policy clear;"
LN
