#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=str
	-pdbName=str
	-prefixService=str
	-poolName=str
"

info "Running : $ME $*"

typeset db=undef
typeset pdbName=undef
typeset poolName=undef
typeset prefixService=undef

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

		-pdbName=*)
			pdbName=${1##*=}
			shift
			;;

		-poolName=*)
			poolName=${1##*=}
			shift
			;;

		-prefixService=*)
			prefixService=${1##*=}
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

[[ $db = undef ]] && [[ -v ID_DB ]] && db=$ID_DB
exit_if_param_undef db				"$str_usage"
exit_if_param_undef pdbName			"$str_usage"
exit_if_param_undef poolName		"$str_usage"
exit_if_param_undef prefixService	"$str_usage"

line_separator
warning "Les services sont créées à partir de notes rapides."
warning "J'ai hacké pour que les services soient créées."
warning "Le but principal étant de poser un mémo"
warning "Donc ils sont foireux et à adapter...."
LN

line_separator
info "create service ${prefixService}_oci on pdb $pdbName (db = $db) attached to pool $poolName"
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

add_dynamic_cmd_param "add service -service ${prefixService}_oci "
add_dynamic_cmd_param "    -pdb $pdbName -db $db -serverpool $poolName"
add_dynamic_cmd_param "    -cardinality    uniform"
add_dynamic_cmd_param "    -policy         automatic"
add_dynamic_cmd_param "    -failovertype   session"
add_dynamic_cmd_param "    -failovermethod basic"
add_dynamic_cmd_param "    -clbgoal        long"
add_dynamic_cmd_param "    -rlbgoal        throughput"

exec_dynamic_cmd srvctl
LN
exec_cmd srvctl start service -service ${prefixService}_oci -db $db
LN

line_separator
#	Services for Application Continuity (java)
info "create service ${prefixService}_java on pdb $pdbName (db = $db) attached to pool $poolName"
LN

add_dynamic_cmd_param "add service -service ${prefixService}_java "
add_dynamic_cmd_param "    -pdb $pdbName -db $db -serverpool $poolName"
add_dynamic_cmd_param "    -cardinality    uniform"
add_dynamic_cmd_param "    -policy         automatic"
add_dynamic_cmd_param "    -failovertype   transaction"
add_dynamic_cmd_param "    -failovermethod basic"
add_dynamic_cmd_param "    -clbgoal        long"
add_dynamic_cmd_param "    -rlbgoal        throughput"
add_dynamic_cmd_param "    -commit_outcome true"

exec_dynamic_cmd srvctl
LN
exec_cmd srvctl start service -service ${prefixService}_java  -db $db
LN

line_separator
exec_cmd srvctl status service -db $db
LN
