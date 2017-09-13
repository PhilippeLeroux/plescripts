#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME

Enable persistent storage of log messages.

Previous boot : journalctl --boot=-1
"

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

LN
info "Enable persistent storage of log messages :"
LN

exec_cmd "mkdir /var/log/journal"
LN

exec_cmd "systemd-tmpfiles --create --prefix /var/log/journal"
LN

exec_cmd "systemctl restart systemd-journald"
LN
