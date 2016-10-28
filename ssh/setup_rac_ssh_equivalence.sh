#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-server1=name
	-server2=name

Doit être exécuté depuis : $client_hostname
Effectue les équivalences ssh nécessaires pour un cluster RAC.
"

script_banner $ME $*

typeset	server1=undef
typeset	server2=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-server1=*)
			server1=${1##*=}
			shift
			;;

		-server2=*)
			server2=${1##*=}
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

exit_if_param_undef server1	"$str_usage"
exit_if_param_undef server2	"$str_usage"

typeset	-r	user_list="root grid oracle"

for user in $user_list
do
	line_separator
	exec_cmd "~/plescripts/ssh/setup_ssh_equivalence.sh	\
					-server1=$server1					\
					-server2=$server2					\
					-user1=$user"
	LN

	exec_cmd "~/plescripts/ssh/setup_ssh_equivalence.sh	\
					-server1=$server1					\
					-server2=$server1					\
					-user1=$user"
	LN

	exec_cmd "~/plescripts/ssh/setup_ssh_equivalence.sh	\
					-server1=$server2					\
					-server2=$server2					\
					-user1=$user"
	LN
done
