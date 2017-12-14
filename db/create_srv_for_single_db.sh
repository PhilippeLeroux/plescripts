#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
	[-role=name] (primary, physical_standby, ${STRIKE}logical_standby, snapshot_standby$NORM)
	[-start=yes]

Si le service existe et que le rôle est définie :
	- avec le CRS le service est modifié en fonction du rôle.
	- sans le CRS pas d'action.

Note : -role agit uniquement sur le nom du service.
"

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
	info "$hostn> $db : create service $service on pluggable database $pdb."
	LN

	if service_exists $db $service
	then
		if [ $role == undef ]
		then
			error "$hostn> Service $service exists and no role specified."
			LN
			info "$str_usage"
			LN
			exit 1
		fi
		action=modify
	else
		action=add
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
	fi

	exec_cmd "~/plescripts/db/add_tns_alias.sh	\
					-service=$service -host_name=$hostn"
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
	info "$hostn> $db : create service $service on pluggable database $pdb."
	LN

	if service_exists $db $service
	then
		if [ $role == undef ]
		then
			error "$hostn> Service $service exist and no role specified."
			LN
			info "$str_usage"
			LN
			exit 1
		fi

		action=modify
	else
		action=add
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

	exec_cmd "~/plescripts/db/add_tns_alias.sh	\
					-service=$service -host_name=$(hostname -s)"
}

#	============================================================================
#	Gestion des services sans le crs (et c'est chiant)

# La variable service doit être déclarée par la fonction appelante.
function start_service_no_crs
{
	# $1 pdb name
	# $2 service name
	function plsql_start_service
	{
		set_sql_cmd "alter session set container=$1;"
		set_sql_cmd "exec dbms_service.start_service( '$2' );"
	}

	info "$hostn> $db[$pdb] : start service $service"
	sqlplus_cmd "$(plsql_start_service $pdb $service)"
	LN
}

# $1 service name
function create_service_no_crs
{
	typeset	-r	service="$1"

	line_separator
	info "$hostn> $db : create service $service on pluggable database $pdb."
	LN

	if service_exists $db $service
	then
		action=modify
		warning "$hostn> modify service without crs nothing to do ?"
		LN
		[[ $start == yes ]] && start_service_no_crs || true
		return 0

		# Code gardé pour éventuelles évolutions.
		if [ $role == undef ]
		then
			error "$hostn> $db[$pdb] : service $service exists and no role specified."
			LN
			info "$str_usage"
			LN
			exit 1
		fi
	else
		action=add
	fi

	# $1 pdb name
	# $2 service name
	function plsql_create_service
	{
		set_sql_cmd "alter session set container=$1;"
		set_sql_cmd "exec dbms_service.create_service( service_name=>'$2', network_name=>'$2' );"
	}

	info "$hostn> $db[$pdb] : create service $service"
	sqlplus_cmd "$(plsql_create_service $pdb $service)"
	LN

	[[ $action == add && $start == yes ]] && start_service_no_crs || true

	exec_cmd "~/plescripts/db/add_tns_alias.sh	\
					-service=$service -host_name=$(hostname -s)"
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

typeset	-r	hostn=$(hostname -s)

if command_exists crsctl
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

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

info "Database $db role = $role"
LN

if [ $crs_used == yes ]
then
	create_or_modify_oci_service

	create_or_modify_java_service
else
	create_or_modify_oci_service_no_crs

	create_or_modify_java_service_no_crs
fi
