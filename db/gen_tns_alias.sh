#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

add_usage "-service=name"							"Service name."
add_usage "-alias_name=name"						"Alias TNS name."
add_usage "-server_list=\"server1 server2 ...\""	"Servers list : for Dataguard 2 servers other only 1."

typeset	-r	str_usage=\
"Usage :
${ME##*/}
$(print_usage)

Definition of alias TNS is printed to stdout.

Samples :
 - Alias for RAC
	${ME##*/} -service=pdb01_java -server_list=\"foo-scan\"
 - Alias for SINGLE
	${ME##*/} -service=pdb666_java -server_list=\"srvfoo01\"
 - Alias for Dataguard
	${ME##*/} -service=pdb1515_java -server_list=\"srvfoo01 srvfoo02\"
"

typeset	service=undef
typeset	alias_name=undef
typeset	server_list=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-service=*)
			service=${1##*=}
			shift
			;;

		-alias_name=*)
			alias_name=${1##*=}
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
exit_if_param_undef alias_name	"$str_usage"
exit_if_param_undef server_list	"$str_usage"

typeset	-ri	count_servers=$(echo "$server_list" | wc -w)

function get_address
{
	for server in $server_list
	do
		echo "			(ADDRESS = (PROTOCOL = TCP) (HOST = $server) (PORT = 1521) )"
	done
}

#	Ouvre la section DESCRIPTION, des options supplémentaires sont affichées pour
#	un dataguard.
function open_section_description
{
	echo "	(DESCRIPTION ="

	[ $count_servers -eq 1 ] && return 0

	echo "		(CONNECT_TIMEOUT= 4) (RETRY_COUNT=20)(RETRY_DELAY=3)"
	echo "		(FAILOVER=on)"
	echo "		(LOAD_BALANCE=off)"
}

# Première ligne vide pour ne pas être collé à l'alias précédent
cat<<EOS

$(to_upper $alias_name) =
$(open_section_description)
		(ADDRESS_LIST=
$(get_address)
		)
		(CONNECT_DATA =
			(SERVER = DEDICATED)
			(SERVICE_NAME = $service)
		)
	)
EOS
