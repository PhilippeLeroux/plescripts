#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
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
			pdb=$(to_upper ${1##*=})
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

#	$1 service name
function test_if_service_exist
{
	typeset -r service=$1
	exec_cmd -ci "srvctl status service -db $db	\
								-service $service" >/dev/null 2>&1
}

function oci_service
{
	line_separator
	info "create service ${prefixService}_oci on pluggable $pdb."
	LN

	test_if_service_exist ${prefixService}_oci
	[ $? -eq 0 ] && action=modify || action=add

	if [[ $action == modify && $role == undef ]]
	then
		error "Service ${prefixService}_oci exist and no role specified."
		LN
		info "$str_usage"
		LN
		exit 1
	fi

	add_dynamic_cmd_param "$action service -service ${prefixService}_oci"
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
			exec_cmd srvctl start service	-service ${prefixService}_oci	\
											-db $db
			LN
		fi

		exec_cmd "~/plescripts/db/add_tns_alias.sh	\
					-service=${prefixService}_oci	\
					-host_name=$(hostname -s)"
		LN
	fi
}

function java_service
{
	line_separator
	#	Services for Application Continuity (java)
	info "create service ${prefixService}_java on pluggable $pdb."
	LN

	test_if_service_exist ${prefixService}_java
	[ $? -eq 0 ] && action=modify || action=add

	if [[ $action == modify && $role == undef ]]
	then
		error "Service ${prefixService}_java exist and no role specified."
		LN
		info "$str_usage"
		LN
		exit 1
	fi

	add_dynamic_cmd_param "$action service -service ${prefixService}_java"
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
		exec_cmd srvctl start service	-service ${prefixService}_java	\
										-db $db
		LN
	fi
}

case "$role" in
	primary|undef)
		typeset -r prefixService=pdb${pdb}
		;;

	physical_standby)
		typeset -r prefixService=pdb${pdb}_stby
		;;

	*)
		error "Role '$role' not supported."
		LN
		info "$str_usage"
		exit 1
esac

oci_service

java_service
