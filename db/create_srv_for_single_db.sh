#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
	[-role=name] (primary, physical_standby, ${STRIKE}logical_standby, snapshot_standby$NORM)
	[-start=yes]

Si le service existe et que le rôle est définie le service est modifié en fonction du rôle.

Pour les RACs : create_srv_for_rac_db.sh
"

script_banner $ME $*

typeset db=undef
typeset pdb=undef
typeset role=undef
typeset start=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-pdb=*)
			pdb=$(to_lower ${1##*=})
			shift
			;;

		-role=*)
			role=${1##*=}
			shift
			;;

		-start=*)
			start=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' unknow."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

if command_exists olsnodes
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

#	http://docs.oracle.com/database/121/RACAD/hafeats.htm#RACAD7026
#	Creating Services for Application Continuity ssi -failovertype TRANSACTION
#	-replay_init_time par défaut 300s
#	-retention par défaut de 1j pour le 'commit outcome'
#	-failoverretry par défaut 30
#	-failoverdelay 10s entre chaque retry.
#	-notification: FAN is highly recommended—set this value to TRUE to enable FAN for OCI and ODP.Net clients.
#
#	Creating Services for Transaction Guard : To enable Transaction Guard, but not Application Continuity
#	-commit_outcome TRUE
#	To use Transaction Guard, a DBA must grant permission, as follows:
#	GRANT EXECUTE ON DBMS_APP_CONT;

#	$1 service name
function test_if_service_exists
{
	typeset -r service=$1
	exec_cmd -ci "srvctl status service -db $db	\
								-service $service" >/dev/null 2>&1
}

function create_or_modify_oci_service
{
	case "$role" in
		primary|undef)
			typeset -r service=$(mk_oci_service $pdb)
			;;

		physical_standby)
			typeset -r service=$(mk_oci_stby_service $pdb)
			;;
	esac

	line_separator
	info "create service $service on pluggable $pdb."
	LN

	test_if_service_exists $service
	[ $? -eq 0 ] && action=modify || action=add

	if [[ $action == modify && $role == undef ]]
	then
		error "Service $service exist and no role specified."
		LN
		info "$str_usage"
		LN
		exit 1
	fi

	add_dynamic_cmd_param "$action service -service $service"
	add_dynamic_cmd_param "    -pdb $pdb -db $db"
	if [ $role != undef ]
	then
		add_dynamic_cmd_param "    -role           $role"
		add_dynamic_cmd_param "    -policy         automatic"
		add_dynamic_cmd_param "    -failovertype   select"
		add_dynamic_cmd_param "    -failovermethod basic"
		add_dynamic_cmd_param "    -failoverretry  20"
		add_dynamic_cmd_param "    -failoverdelay  3"
		add_dynamic_cmd_param "    -clbgoal        long"
		add_dynamic_cmd_param "    -rlbgoal        throughput"
	fi

	exec_dynamic_cmd srvctl
	LN

	if [ $action == add ]
	then
		if [ $start == yes ]
		then
			exec_cmd srvctl start service -service $service -db $db
			LN
		fi

		exec_cmd "~/plescripts/db/add_tns_alias.sh	\
						-service=$service -host_name=$(hostname -s)"
		LN
	fi
}

function create_or_modify_java_service
{
	case "$role" in
		primary|undef)
			typeset -r service=$(mk_java_service $pdb)
			;;

		physical_standby)
			typeset -r service=$(mk_java_stby_service $pdb)
			;;
	esac

	line_separator
	#	Services for Application Continuity (java)
	info "create service $service on pluggable $pdb."
	LN

	test_if_service_exists $service
	[ $? -eq 0 ] && action=modify || action=add

	if [[ $action == modify && $role == undef ]]
	then
		error "Service $service exist and no role specified."
		LN
		info "$str_usage"
		LN
		exit 1
	fi

	add_dynamic_cmd_param "$action service -service $service"
	add_dynamic_cmd_param "    -pdb $pdb -db $db"
	if [ $role != undef ]
	then
		add_dynamic_cmd_param "    -role             $role"
		add_dynamic_cmd_param "    -policy           automatic"
#	----------------------------------------------------------------------------
#	Ne fonctionne pas : aq_ha_notification non activé : RAC only
#		add_dynamic_cmd_param "    -failovertype     TRANSACTION"
#		add_dynamic_cmd_param "    -replay_init_time 600"
#		add_dynamic_cmd_param "    -commit_outcome   TRUE"
#	----------------------------------------------------------------------------
		add_dynamic_cmd_param "    -failovertype     SELECT"
		add_dynamic_cmd_param "    -failovermethod   basic"
		add_dynamic_cmd_param "    -failoverretry    30"
		add_dynamic_cmd_param "    -failoverdelay    1"
	#	add_dynamic_cmd_param "    -clbgoal        long"
	#	add_dynamic_cmd_param "    -rlbgoal        throughput"
	fi

	exec_dynamic_cmd srvctl
	LN

	if [[ $action == add && $start == yes ]]
	then
		exec_cmd srvctl start service -service $service -db $db
		LN
	fi
}

#	============================================================================
#	Gestion des services sans le crs (et c'est chiant)

#	$1 service name
function test_if_service_exists_no_crs
{
	typeset -r service=$1
	exec_cmd -c "lsnrctl status | grep -q 'Service \"$service\" has .*'"
}

# Variable service defined by caller.
function create_service_no_crs
{
	line_separator
	info "create service $service on pluggable $pdb."
	LN

	test_if_service_exists_no_crs $service
	[ $? -eq 0 ] && action=modify || action=add

	if [ $action == modify ]
	then
		error "modify service without crs not implemanted."
		LN
		exit 1
	fi

	if [[ $action == modify && $role == undef ]]
	then
		error "Service $service exist and no role specified."
		LN
		info "$str_usage"
		LN
		exit 1
	fi

	function plsql_create_service
	{
		set_sql_cmd "exec dbms_service.create_service( service_name=>'$service', network_name=>'$service' );"
	}

	info "Create service $service"
	sqlplus_cmd_with	"sys/$oracle_password@localhost:1521/$pdb as sysdba" \
						"$(plsql_create_service)"
	LN

	if [ $action == add ]
	then
		if [ $start == yes ]
		then
			function plsql_start_service
			{
				set_sql_cmd "alter session set container=$pdb;"
				set_sql_cmd "exec dbms_service.start_service( '$service' );"
			}
			info "Start service $service"
			sqlplus_cmd "$(plsql_start_service)"
			LN
		fi

		exec_cmd "~/plescripts/db/add_tns_alias.sh	\
						-service=$service -host_name=$(hostname -s)"
		LN
	fi
}

function create_or_modify_oci_service_no_crs
{
	case "$role" in
		primary|undef)
			typeset -r service=$(mk_oci_service $pdb)
			;;

		physical_standby)
			typeset -r service=$(mk_oci_stby_service $pdb)
			;;
	esac

	create_service_no_crs $service
}

function create_or_modify_java_service_no_crs
{
	case "$role" in
		primary|undef)
			typeset -r service=$(mk_java_service $pdb)
			;;

		physical_standby)
			typeset -r service=$(mk_java_stby_service $pdb)
			;;
	esac

	create_service_no_crs $service
}

function create_database_trigger_no_crs
{
typeset query=\
"select
	trigger_name
from
	dba_triggers
where
	trigger_name = 'START_PDB_SERVICES'
;"
	typeset pdbconn="sys/$oracle_password@localhost:1521/$pdb as sysdba"
	typeset trigger=$(sqlplus_exec_query_with "$pdbconn" "$query"|tail -1)
	if [ "$trigger" != "START_PDB_SERVICES" ]
	then
		info "Create trigger start_pdb_services"
		sqlplus_cmd_with "$pdbconn"  "$(set_sql_cmd "@$HOME/plescripts/db/sql/create_trigger_start_pdb_services.sql")"
		LN
	fi
}

case "$role" in
	primary|undef|physical_standby)
		:
		;;

	*)
		error "Role '$role' not supported."
		LN
		info "$str_usage"
		exit 1
esac

if [ $crs_used == yes ]
then
	create_or_modify_oci_service

	create_or_modify_java_service
else
	create_database_trigger_no_crs

	create_or_modify_oci_service_no_crs

	create_or_modify_java_service_no_crs
fi
