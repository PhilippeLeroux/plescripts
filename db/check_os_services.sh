#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

#ple_enable_log -params $PARAMS

exec_cmd "systemctl --failed"
LN

exec_cmd "systemctl status ohasd.service"
LN

exec_cmd "systemctl status oracle-ohasd.service"
LN

exec_cmd "tuned-adm active"
LN

exec_cmd "sysctl vm.swappiness"
LN
