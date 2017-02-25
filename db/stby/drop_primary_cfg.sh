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
			first_args=-emul
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
	dgmgrl -silent -echo<<-EOS  | tee -a $PLELIB_LOG_FILE
	connect sys/$oracle_password
	disable configuration;
	remove configuration;
	EOS
	LN

	line_separator
	exec_cmd -c sudo -u grid -i "asmcmd rm -f DATA/$db/dr1db_*.dat"
	LN
}

function remove_database_from_broker
{
	line_separator
	dgmgrl -silent -echo<<-EOS | tee -a $PLELIB_LOG_FILE
	connect sys/$oracle_password
	disable database $db;
	remove database $db;
	EOS
	LN

	line_separator
	exec_cmd -c sudo -u grid -i "asmcmd rm -f DATA/$db/dr1db_*.dat"
	LN
}

function remove_SRLs
{
	line_separator
	sqlplus_cmd "@drop_standby_redolog.sql"
	LN
if [ 0 -eq 1 ]; then
	sqlplus -s sys/$oracle_password as sysdba<<-EOS
	@drop_standby_redolog.sql
	EOS
	LN
fi # [ 0 -eq 1 ]; then
}

function drop_services
{
	line_separator
	exec_cmd -c ~/plescripts/db/drop_all_services.sh -db=$db
	LN
}

function create_services
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

typeset -r role_cfg=$(read_database_role $(to_lower $db))

info "$db role=$role, role read from configuration : $role_cfg"

if [[ x"$role_cfg" != x && "$role" != "$role_cfg" ]]
then
	error "role $role invalid ?"
	LN
fi

if [ $role == physical ]
then
	function convert_to_primary
	{
		set_sql_cmd "alter database recover managed standby database cancel;"
		set_sql_cmd "alter database recover managed standby database finish;"
		set_sql_cmd "alter database commit to switchover to primary with session shutdown;"
		set_sql_cmd "alter database open;"
	}
	exec_cmd srvctl stop database -db $db
	exec_cmd srvctl start database -db $db -startoption mount
	sqlplus_cmd "$(convert_to_primary)"

	remove_database_from_broker
else
	remove_broker_cfg
fi

remove_SRLs

drop_services

create_services

line_separator
sqlplus_cmd "$(sqlcmd_reset_dataguard_cfg)"
if [ $role == physical ]
then
	exec_cmd srvctl modify database -db $db -startoption open
	exec_cmd srvctl modify database -db $db -role primary
fi
# startup avec sqlplus ne fonctionne pas avec le wallet.
exec_cmd srvctl start database -db $db
LN
