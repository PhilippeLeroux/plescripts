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
	[-service=auto]	if no service used : localhost:1521
"

typeset db=undef
typeset pdb=undef
typeset service=auto

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

		-service=*)
			service=${1##*=}
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

must_be_user oracle

ORACLE_SID=$(~/plescripts/db/get_active_instance.sh)
info "Load env for ORACLE_SID=$ORACLE_SID"
ORAENV_ASK=NO . oraenv
LN

# $1 account name
function ddl_set_password_and_unlock_account
{
	typeset -r account=$1
	set_sql_cmd "alter user $account identified by $account;"
	set_sql_cmd "alter user $account account unlock;"
}

function ddl_unlock_all_accounts
{
#	set_sql_cmd "whenever sqlerror exit 1;"
	ddl_set_password_and_unlock_account IX
	ddl_set_password_and_unlock_account SH
	ddl_set_password_and_unlock_account BI
	ddl_set_password_and_unlock_account OE
	ddl_set_password_and_unlock_account HR
	ddl_set_password_and_unlock_account PM
	ddl_set_password_and_unlock_account SCOTT
}

if command_exists olsnodes
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

case "$service" in
	"localhost:1521")
		service="$service/$pdb"
		;;
	auto)
		service=$(mk_oci_service $pdb)
		[ $crs_used == yes ] && exit_if_service_not_running $db $service || true
		;;
	*)
		[ $crs_used == yes ] && exit_if_service_not_running $db $service || true
esac

sqlplus_cmd_with sys/$oracle_password@"$service" as sysdba	\
								"$(ddl_unlock_all_accounts)"
