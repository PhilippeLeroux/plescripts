#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC
PAUSE=OFF

typeset -r ME=$0
typeset -r str_usage=\
"Usage :
$ME
	[-pause=$PAUSE]	ON|OFF

Note : ne fonctionne pas sur Oracle 12.1 sur ASM et le wallet d'activé.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-pause=*)
			PAUSE=$(to_upper ${1##*=})
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

ple_enable_log

script_banner $ME $*

exit_if_ORACLE_SID_not_defined

function cleanup_on_exit
{
	info "Remove temporaries scripts"
	exec_cmd -f rm -rf /tmp/*.$$
	LN
}

trap cleanup_on_exit EXIT

# $1 name sql file
# write to $1 all commands to clear ORLs & SRLs
function create_sql_script_to_clear_all_redo
{
	typeset -r sql_script="$1"

	info "Create script to clear all redologs"

	fake_exec_cmd "sqlplus -s sys/$oracle_password as sysdba<<-EOSQL"
	sqlplus -s sys/$oracle_password as sysdba<<-EOSQL >/dev/null 2>&1
	set heading off
	set underline off
	set echo off feed off
	spool $sql_script
	set termout off
	select
		'alter database clear logfile group '||group#||';'
	from
		( select distinct group# from v\$logfile order by group# )
	;
	spool off
	EOSQL
	echo "exit" >> $sql_script

	exec_cmd -f "cat $sql_script"
	LN
}

function stby_stop_redo_apply
{
	line_separator
	info "$ORACLE_SID : stop redo apply"
	exec_cmd dgmgrl -silent -echo sys/$oracle_password	\
				\"edit database $ORACLE_SID set state='APPLY-OFF'\"
	LN
}

function stby_start_redo_apply
{
	line_separator
	info "$ORACLE_SID : start redo apply"
	exec_cmd dgmgrl -silent -echo sys/$oracle_password	\
				\"edit database $ORACLE_SID set state='APPLY-ON'\"
	LN
}

# Affiche sur stdout le scn courant
function stby_read_current_scn
{
	sqlplus -s sys/$oracle_password as sysdba<<-EOSQL | tail -1
	set numformat 999999999
	set heading off echo off feed off underline off
	select current_scn from v\$database;
	EOSQL
}

function stby_restart_nomount
{
	function sql_cmd_restart
	{
		set_sql_cmd shutdown immediate;
		set_sql_cmd startup nomount;
	}

	line_separator
	info "Start $ORACLE_SID to nomount"
	sqlplus_cmd "$(sql_cmd_restart)"
	LN
}

# $1 nom du service pour communiquer avec la Primary Database
function stby_restore_controlfile_from_service
{
	typeset	-r primary_service="$1"
	typeset -r script="/tmp/rman_restore_ctl.$$"

	line_separator
	info "Restore controlfile and start database to mount state."

	info "Create rman script"
	cat<<-EOS>$script
	restore standby controlfile from service $primary_service;
	alter database mount;
	EOS
	exec_cmd -f "cat $script"
	LN

	info "Execute rman script"
	exec_cmd rman target sys/$oracle_password @$script
	LN
}

# $1 chemin de la FRA pour le cataloguage.
# Catalogue la FRA & switch database to copy
function stby_catalog_FRA_and_switch_database_to_copy
{
	typeset	-r FRA_name="$1"
	typeset -r script=/tmp/rman_catalog_switch.$$

	line_separator
	info "Catalog $FRA_name & switch database to copy"
	info "Create script"
	cat<<-EOS>$script
	catalog start with '${FRA_name}/';
	switch database to copy;
	EOS
	exec_cmd -f "cat $script"
	LN

	info "Execute script"
	exec_cmd "rman target sys/$oracle_password @$script"
	LN
}

# $1 nom du service pour communiquer avec la Primary Database
function stby_recover_database_from_service
{
	typeset	-r primary_service="$1"
	typeset	-r script="/tmp/rman_refresh_stby.$$"

	line_separator
	info "Recover database $ORACLE_SID from $primary_service"
	info "Create script"
	exec_cmd -f "echo 'recover database from service $primary_service noredo using compressed backupset;'>$script"
	LN
	info "Execute script"
	exec_cmd "rman target sys/$oracle_password @$script"
	LN
}

# $1 scn lue avant d'effectuer la synchronisation.
function stby_abort_if_new_datafiles
{
typeset -r query_count=\
"select
	count(*)
from
	v\$datafile
where
	creation_change# >= $1
;"
typeset -r query_print=\
"select
	file#
from
	v\$datafile
where
	creation_change# >= $1
;"

	line_separator
	typeset -r nb_new_dbf=$(sqlplus_exec_query "$query_count"|xargs)
	if [ $nb_new_dbf -ne 0 ]
	then
		error "Il est nécessaire de restaurer $nb_new_dbf dbfs"
		error "Le script ne prend pas encore en charge cette action."
		error "Voir la doc oracle section 13"
		error "Puis relancer le script avec le flag -skip_recover"
		LN

		info "Liste des nouveaux dbfs."
		sqlplus_print_query "$query_print"
		LN
		exit 1
	else
		info "Pas de dbfs ajoutés sur la standby [$OK]"
		LN
	fi
}

# $1 nom du script permettant de 'clearer' les redos.
function stby_clearing_all_redos
{
	typeset -r script="$1"

	line_separator
	info "Clearing all redos."
	info "Execute script $script"
	exec_cmd "sqlplus -s sys/$oracle_password as sysdba @$script"
	LN
}

# $1 service permettant de se connecter à la Primary Database
function primary_archive_log_current
{
	line_separator
	info "Switch archive log sur la Primary $1"
	function sqlcmd_archive_log
	{
		# Une seule commande suffit mais pas sur mes démo avec ASM
		set_sql_cmd alter system archive log current;
		set_sql_cmd alter system archive log current;
		set_sql_cmd alter system archive log current;
	}
	sqlplus_cmd_with "sys/$oracle_password@$1 as sysdba" "$(sqlcmd_archive_log)"
	LN
}

function stby_recover_database_and_open_RO
{
	function sql_cmds
	{
		set_sql_cmd "alter database flashback on;"
		set_sql_cmd "alter database open read only;"
	}

	typeset -r rman_script=/tmp/recover_stby.$$
	line_separator
	info "Recover database"
	info "Create script"
	exec_cmd -f "echo 'alter database recover managed standby database until consistent;'>$rman_script"
	info "Execute script"
	exec_cmd "rman target sys/$oracle_password @$rman_script"
	LN

	info "Enable flashback & open database RO"
	sqlplus_cmd "$(sql_cmds)"
	LN
}

function stby_crosscheck_FRA
{
	line_separator
	info "Crosscheck FRA"
	exec_cmd "rman target sys/Oracle12 @$HOME/plescripts/db/rman/crosscheck.rman"
	LN
}

typeset	-r	primary_db_name="$(read_primary_name)"
typeset -ri stby_current_scn=$(stby_read_current_scn)
typeset	-r	stby_FRA_name="$(orcl_parameter_value db_recovery_file_dest)"
typeset -r	dbrole="$(read_database_role $ORACLE_SID)"

info "Primary database : $primary_db_name"
LN

info "ORACLE_SID  : $ORACLE_SID"
info "role        : $dbrole"
info "current scn : $stby_current_scn"
info "FRA         : $stby_FRA_name"
LN

if [ "$dbrole" != "physical" ]
then
	error "Mauvais rôle, doit être physical"
	LN
	exit 1
fi

line_separator
typeset	-r sql_clear_all_redos=/tmp/sql_clear_all_redos.$$
create_sql_script_to_clear_all_redo $sql_clear_all_redos
test_pause

stby_stop_redo_apply
test_pause

stby_restart_nomount
test_pause

stby_restore_controlfile_from_service $primary_db_name
test_pause

stby_catalog_FRA_and_switch_database_to_copy "$stby_FRA_name"
test_pause

stby_recover_database_from_service $primary_db_name
test_pause

stby_abort_if_new_datafiles $stby_current_scn
test_pause

stby_clearing_all_redos $sql_clear_all_redos
test_pause

primary_archive_log_current $primary_db_name
test_pause

stby_recover_database_and_open_RO
test_pause

stby_start_redo_apply
test_pause

stby_crosscheck_FRA
