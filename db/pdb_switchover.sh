#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

# Doc :
# https://docs.oracle.com/en/database/oracle/oracle-database/18/multi/administering-pdbs-with-sql-plus.html#GUID-B505C234-FAF4-4BAB-8B59-59276E0EA128

typeset	-r	str_usage=\
"Usage :
$ME
    -db=name
	-pdb=name
	-remote_host=name 
	-remote_db=name
	[-remote_pdb=name]    if missing take value of parameter -pdb

For the moment only for refresh manual.

NOTE :
    PDB switchover don't work with 18c :
    ERREUR a la ligne 1 :
    ORA-12754: Feature PDB REFRESH SWITCHOVER is disabled due to missing capability
"

typeset		db=undef
typeset		pdb=undef
typeset		remote_host=undef
typeset		remote_db=undef
typeset		remote_pdb=none

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

		-remote_host=*)
			remote_host=${1##*=}
			shift
			;;

		-remote_db=*)
			remote_db=${1##*=}
			shift
			;;

		-remote_pdb=*)
			remote_pdb=${1##*=}
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

ple_enable_log -params $PARAMS

exit_if_param_undef db			"$str_usage"
exit_if_param_undef pdb			"$str_usage"
exit_if_param_undef remote_host	"$str_usage"
exit_if_param_undef remote_db	"$str_usage"

# $1 pdb name
# $2 remote pdb name
# $3 dblink name
#
# Print to stdout all ddl statements to do a PDB switch over.
function ddl_switchover_pdb
{
	set_sql_cmd "whenever sqlerror exit 1"
	set_sql_cmd "alter session set container = $1;"
	set_sql_cmd "alter pluggable database refresh mode manual from $2@$3 switchover;"
}

# $1 pdb name
#
# Print to stdout all ddl statements to refresh a refreshable PDB.
function ddl_refresh_pdb
{
	set_sql_cmd "whenever sqlerror exit 1"
	set_sql_cmd "alter session set container = $1;"
	set_sql_cmd "alter pluggable database refresh;"
}

# $1 pdb name
#
# Print to stdout all ddl statements to open RO a PDB.
function ddl_open_ro_pdb
{
	set_sql_cmd "whenever sqlerror exit 1"
	set_sql_cmd "alter session set container = $1;"
	set_sql_cmd "alter pluggable database open read only;"
}

# $1 pdb name
#
# Print to stdout all ddl statements to close a PDB.
function ddl_close_pdb
{
	set_sql_cmd "whenever sqlerror exit 1"
	set_sql_cmd "alter session set container = $1;"
	set_sql_cmd "alter pluggable database close immediate;"
}

case $(read_orcl_version) in
	12*)
		error "Not implemented in 12c."
		LN
		exit 1
		;;
esac

typeset	-r	dblink_name=cdb_${remote_db}
typeset	-r	common_user="c##u1"
typeset	-r	tnsalias=$remote_db
[ $remote_pdb == none ] && remote_pdb=$pdb || true

if ! dblink_exists $dblink_name
then
	line_separator
	info "Create TNS alias $tnsalias for dblink $dblink_name"
	exec_cmd "~/plescripts/db/add_tns_alias.sh			\
								-service=${remote_db}	\
								-host_name=$remote_host	\
								-tnsalias=$tnsalias"

	exit_if_tnsping_failed $remote_db

	line_separator
	info "Create database link $dblink_name (For refresh or cloning PDB)"
	sqlplus_cmd "$(ddl_create_dblink $dblink_name $common_user $oracle_password $tnsalias)"
	LN
else
	info "Database link $dblink_name exists."
	LN
fi

exit_if_test_dblink_failed $dblink_name

# J'ai testé sur la base en mode refresh, mais ca ne change rien.
if refreshable_pdb $pdb
then
	warning "Only for test !"
	confirm_or_exit "Must be executed on source database, continue"

	line_separator
	sqlplus_cmd "$(ddl_refresh_pdb $pdb $dblink_name)"
	[ $? -eq 1 ] && exit 1 || true
	LN

	# Ne marche pas non plus en RO.
	#sqlplus_cmd "$(ddl_open_ro_pdb $pdb)"
	[ $? -eq 1 ] && exit 1 || true
	LN
else
	line_separator
	info "Refresh $remote_db[$remote_pdb]"
	typeset	-r remote_connstr="sys/$oracle_password@$remote_db as sysdba"
	sqlplus_cmd_with "$remote_connstr" "$(ddl_refresh_pdb $remote_pdb $dblink_name)"
	LN
fi

line_separator
info "Start switch over."
LN

if sqlplus_cmd "$(ddl_switchover_pdb $pdb $remote_pdb $dblink_name)"
then
	info "switchover [$OK]"
	LN
	exit 0
else
	error "switchover [$KO]"
	LN
	exit 1
fi
