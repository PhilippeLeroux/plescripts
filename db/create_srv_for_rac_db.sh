#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
	[-poolName=name]    For policy managed database.

For single database used : create_srv_for_single_db.sh
"

script_banner $ME $*

typeset db=undef
typeset pdb=undef
typeset poolName
typeset preferredInstances

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
			pdb=${1##*=}
			shift
			;;

		-poolName=*)
			poolName=${1##*=}
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

exit_if_param_undef db				"$str_usage"
exit_if_param_undef pdb				"$str_usage"

line_separator
warning "Les services sont créées à partir de notes rapides."
warning "J'ai hacké pour que les services soient créées."
warning "Le but principal étant de poser un mémo"
warning "Donc ils sont foireux et à adapter...."
LN

# print all instances to stdout
function get_all_instances
{
	typeset list
	while read w1 instanceName rem
	do
		[ x"$list" == x ] && list=$instanceName || list="$list,$instanceName"
	done<<<"$(srvctl status database -db $db)"

	echo $list
}

#	print scan name to stdout
function get_scan_name
{
	srvctl config scan | head -1 | sed "s/.*: \(.*-scan\),.*/\1/"
}

typeset -r oci_service=$(mk_oci_service $pdb)
typeset -r java_service=$(mk_java_service $pdb)
typeset	-r scan_name=$(get_scan_name)

line_separator
if [ x"$poolName" == x ]
then
	preferredInstances=$(get_all_instances)
	info "Create service Administrator Managed $oci_service"
else
	info "Create service Policy Managed $oci_service"
fi
LN

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

add_dynamic_cmd_param "add service -service $oci_service"
add_dynamic_cmd_param "    -pdb $pdb -db $db"
if [ x"$poolName" == x ]
then
	add_dynamic_cmd_param "    -preferred      $preferredInstances"
else
	add_dynamic_cmd_param "    -serverpool     $poolName"
	add_dynamic_cmd_param "    -cardinality    uniform"
fi
add_dynamic_cmd_param "    -policy         automatic"
add_dynamic_cmd_param "    -failovertype   session"
add_dynamic_cmd_param "    -failovermethod basic"
add_dynamic_cmd_param "    -clbgoal        long"
add_dynamic_cmd_param "    -rlbgoal        throughput"

exec_dynamic_cmd srvctl
LN
exec_cmd srvctl start service -service $oci_service -db $db
LN

exec_cmd "~/plescripts/db/add_tns_alias.sh			\
				-service=$oci_service				\
				-host_name=$scan_name				\
				-copy_server_list=\"${gi_node_list}\""
LN

line_separator
#	Services for Application Continuity (java)
if [ x"$poolName" == x ]
then
	info "Create service Administrator Managed $java_service"
else
	info "Create service Policy Managed $java_service"
fi
LN

add_dynamic_cmd_param "add service -service $java_service"
add_dynamic_cmd_param "    -pdb $pdb -db $db"
if [ x"$poolName" == x ]
then
	add_dynamic_cmd_param "    -preferred      $preferredInstances"
else
	add_dynamic_cmd_param "    -serverpool     $poolName"
	add_dynamic_cmd_param "    -cardinality    uniform"
fi
add_dynamic_cmd_param "    -policy         automatic"
add_dynamic_cmd_param "    -failovertype   transaction"
add_dynamic_cmd_param "    -failovermethod basic"
add_dynamic_cmd_param "    -clbgoal        long"
add_dynamic_cmd_param "    -rlbgoal        throughput"
add_dynamic_cmd_param "    -commit_outcome true"

exec_dynamic_cmd srvctl
LN

exec_cmd srvctl start service -service $java_service -db $db
LN

line_separator
exec_cmd srvctl status service -db $db
LN
