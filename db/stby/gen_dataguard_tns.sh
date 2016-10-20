#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

typeset service=undef
typeset server_list=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-service=*)
			service=${1##*=}
			shift
			;;

		-server_list=*)
			server_list=${1##*=}
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

exit_if_param_undef service		"$str_usage"
exit_if_param_undef server_list	"$str_usage"

function get_address
{
	for server in $server_list
	do
		echo "			(ADDRESS = (PROTOCOL = TCP) (HOST = $server) (PORT = 1521) )"
	done
}

cat<<EOS
$(to_upper $service) =
	(DESCRIPTION =
		(FAILOVER=on)
		(LOAD_BALANCE=off)
		(ADDRESS_LIST=
$(get_address)
		)
		(CONNECT_DATA =
			(SERVER = DEDICATED)
			(SERVICE_NAME = $service)
		)
	)
EOS
