#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name

Options for policy managed database :
	[-poolName=name]        Not defined => Administrator Managed Database.
	[-cardinality=uniform]  uniform | singleton

Options for administrator managed database :
	[-preferred=name]       Default all instances.
	[-available=name]       Default none.
"

typeset db=undef
typeset pdb=undef
typeset poolName
typeset cardinality=uniform
typeset preferred
typeset available

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

		-cardinality=*)
			cardinality=${1##*=}
			shift
			;;

		-preferred=*)
			preferred=${1##*=}
			shift
			;;

		-available=*)
			available=${1##*=}
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

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_param_invalid cardinality "uniform singleton"	"$str_usage"

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

#	for administrator managed database add parameter -preferred and/or -available
function add_param_preferred_available
{
	if [ x"$preferred" == x ]
	then # default on all instances.
		add_dynamic_cmd_param "    -preferred      $(get_all_instances)"
	else
		add_dynamic_cmd_param "    -preferred      $preferred"
		if [ "$available" == x ]
		then
			add_dynamic_cmd_param "    -available      $available"
		fi
	fi
}

#	for policy managed database.
function add_param_serverpool
{
	add_dynamic_cmd_param "    -serverpool     $poolName"
	add_dynamic_cmd_param "    -cardinality    $cardinality"
}

typeset -r oci_service=$(mk_oci_service $pdb)
typeset -r java_service=$(mk_java_service $pdb)
typeset	-r scan_name=$(get_scan_name)

warning "Les services sont créées à partir de notes rapides."
warning "J'ai hacké pour que les services soient créées."
warning "Le but principal étant de poser un mémo"
warning "Donc ils sont foireux et à adapter...."
LN

line_separator
if [ x"$poolName" == x ]
then
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
[ x"$poolName" == x ] && add_param_preferred_available || add_param_serverpool
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
[ x"$poolName" == x ] && add_param_preferred_available || add_param_serverpool
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
