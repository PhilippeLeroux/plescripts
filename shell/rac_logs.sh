#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset -r asm_inst=$(ps -ef|grep pmon_+ASM | grep -v grep | cut -d_ -f3)

tmux new -s RacLogs "tail -f /u01/app/grid/diag/crs/$(hostname -s)/crs/trace/alert.log" \; \
		split-window -v "tail -f /u01/app/grid/diag/asm/+asm/$asm_inst/trace/alert_$asm_inst.log"

