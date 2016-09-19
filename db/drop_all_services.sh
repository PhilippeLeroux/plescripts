#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=name"

info "Running : $ME $*"

typeset	db=undef

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

while read label serviceName w1 w2 w3
do
	[ x"$label" == x ] && continue

	if [ "$w2" == "running" ]
	then
		exec_cmd srvctl stop service -db $db -service $serviceName
	fi

	exec_cmd srvctl remove service -db $db -service $serviceName
	LN
done<<<"$(srvctl status service -db $db)"
