#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -user=name -server=name"

script_banner $ME $*

typeset user=undef
typeset server=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-user=*)
			user=${1##*=}
			shift
			;;

		-server=*)
			server=${1##*=}
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

exit_if_param_undef user	"$str_usage"
exit_if_param_undef server	"$str_usage"

exec_cmd -c ssh -o BatchMode=yes $user@$server true
if [ $? -ne 0 ]
then
	error "No ssh equi between $USER@$(hostname -s) & $user@$server"
	exit 1
fi
