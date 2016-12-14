#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

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

#	UID        PID  PPID  C STIME TTY          TIME CMD
function stop_vboxmanager
{
	typeset	-r	strid="/[u]sr/[l]ib/virtualbox/VirtualBox"

	fake_exec_cmd "ps -ef|grep -E '$strid'|grep -v bash | awk '{ printf \$2 }'"
	typeset	pid=$(ps -ef|grep -E "$strid"|grep -v bash | awk '{ printf $2 }')
	if [ x"$pid" == x ]
	then
		info "Vbox Manager not running."
		exit 0
	fi

	info "Stop Vbox Manager, process $pid"
	exec_cmd kill -15 $pid
	timing 2 "Waiting Vbox Manager"
	LN

	pid=$(ps -ef|grep -E "$strid" | awk '{ printf $2 }')
	[ x"$pid" == x ] && return 0 || true

	error "Failed to stop Vbox Manager"
	exit 1
}

stop_vboxmanager

info "Start VBox Manager"
nohup VirtualBox > /tmp/vv.nohup 2>&1 &
LN
