#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-service=name"

script_banner $ME $*

typeset db=undef
typeset service=undef

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

[[ $db = undef ]] && [[ -v ID_DB ]] && db=$ID_DB
exit_if_param_undef db		"$str_usage"
exit_if_param_undef service	"$str_usage"

function is_running
{
	typeset	-r	db=$1
	typeset	-r	service=$2

	srvctl status service -db $db -service $service | grep -q "is running"
}

if $(is_running $db $service)
then
	exec_cmd srvctl stop service -db $db -service $service
	LN
fi

exec_cmd srvctl remove service -db $db -service $service
LN

exec_cmd ~/plescripts/db/delete_tns_alias.sh -alias_name=$service
LN
