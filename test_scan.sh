#!/bin/sh

#	ts=4	sw=4

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

typeset -r scan_name=$(olsnodes -c)

info "Test $scan_name"
for i in $( seq 1 3 )
do
	info "Ping $i"
	exec_cmd ping -c 1 $scan_name
	LN
done

info "nslookup"
exec_cmd nslookup $scan_name
