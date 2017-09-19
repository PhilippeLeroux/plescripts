#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -i	max_load_avg=3

typeset -r str_usage=\
"Usage : $ME
	[-max_load_avg=$max_load_avg] minimum 1
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-max_load_avg=*)
			max_load_avg=${1##*=}
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

exit_if_param_undef max_load_avg	"$str_usage"

if [ $max_load_avg -lt 1 ]
then
	error "-max_load_avg=$max_load_avg to low, minimum 1"
	LN
	exit 1
fi

typeset -i load_avg=0
while true
do
	IFS=\  read tt up min lminn users lusers load average mn1 mn5 mn15	\
														<<<"$(LANG=C uptime)"
	load_avg_str="$(cut -d, -f1<<<"$mn1")"
	load_avg=$(cut -d. -f1<<<"$load_avg_str")

	info "Load average : $load_avg_str, max $max_load_avg"

	[ $load_avg -lt $max_load_avg ] && break || true

	timing 60
	LN
done
LN
