#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

ple_enable_log

exec_cmd "hostname"
LN
exec_cmd "uname -m"
LN
exec_cmd "free -m"
LN
exec_cmd "df -m /dev/shm"
LN
exec_cmd sysctl vm.nr_hugepages
LN

exec_cmd "ulimit -a"
LN

exec_cmd "cat /etc/os-release"
