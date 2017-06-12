#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

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

script_banner $ME $*

ple_enable_log

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

	set_sql_cmd "shutdown immediate"
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
	exec_cmd -c sudo -u grid -i "asmcmd rm -f DATA/$db/dr1db_*.dat"
	LN
	exec_cmd -c sudo -u grid -i "asmcmd rm -f FRA/$db/dr2db_*.dat"
	LN
}

function remove_database_from_broker
{
	line_separator
	fake_exec_cmd dgmgrl
	dgmgrl -silent -echo<<-EOS | tee -a $PLELIB_LOG_FILE
	connect sys/$oracle_password
	remove database $db;
	EOS
	LN

	exec_cmd -c sudo -u grid -i "asmcmd rm -f DATA/$db/dr1db_*.dat"
	exec_cmd -c sudo -u grid -i "asmcmd rm -f FRA/$db/dr2db_*.dat"
	LN
}

function convert_physical_to_primary
{
	function sql_convert_to_primary
	{
		set_sql_cmd "recover managed standby database finish;"
		set_sql_cmd "alter database commit to switchover to primary with session shutdown;"
		set_sql_cmd "alter database open;"
	}
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
	sqlplus_cmd "$(sql_convert_to_primary)"
	LN
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
		exec_cmd -c ~/plescripts/db/fsdb_drop_all_services.sh -db=$db
		LN
	fi
}

function create_services_for_single_db
{
typeset -r query=\
"select
	c.name
from
	gv\$containers c
	inner join gv\$instance i
		on  c.inst_id = i.inst_id
	where
		i.instance_name = '$db'
	and	c.name not in ( 'PDB\$SEED', 'CDB\$ROOT', 'PDB_SAMPLES' );
"

	while read pdb
	do
		[ x"$pdb" == x ] && continue

		line_separator
		exec_cmd "~/plescripts/db/create_srv_for_single_db.sh -db=$db -pdb=$pdb"
		LN
	done<<<"$(sqlplus_exec_query "$query")"
}

exit_if_database_not_exists $db

load_oraenv_for $db

if test_if_cmd_exists crsctl
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

typeset -r role_cfg=$(read_database_role $(to_lower $db))

info "$db role=$role, role read from configuration : $role_cfg"

if [[ x"$role_cfg" != x && "$role" != "$role_cfg" ]]
then
	error "role $role invalid ?"
	LN
	exit 1
fi

if [ $role == physical ]
then
	convert_physical_to_primary

	remove_database_from_broker
else
	remove_broker_cfg
fi

remove_SRLs

drop_all_services

create_services_for_single_db

line_separator
sqlplus_cmd "$(sqlcmd_reset_dataguard_cfg)"
LN

if [[ $role == physical && $crs_used == yes ]]
then
	exec_cmd srvctl modify database -db $db -startoption open
	exec_cmd srvctl modify database -db $db -role primary
	LN
fi

if [ $crs_used == yes ]
then # startup avec sqlplus ne fonctionne pas avec le wallet.
	exec_cmd srvctl start database -db $db
	LN
else
	sqlplus_cmd "$(set_sql_cmd startup)"
	LN
fi
