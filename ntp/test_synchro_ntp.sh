#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset	-i	max_seconds=$((8*60))

typeset -r	str_usage=\
"Usage :
	$ME [-max_seconds=$max_seconds]"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-max_seconds=*)
			max_seconds=${1##*=}
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

typeset -ri	start_at_s=$SECONDS
typeset -r	hn=$(hostname -s)

typeset	-i	wait_time=10

info "Test ntp synchronization for $(fmt_seconds $max_seconds) maximum."
LN

while true
do
	while read w1 w2 rem
	do
		[[ "$w2" == "" || "$w1" == "remote" ]] && continue || true

		info "$hn sync state : $w1"
		if [ "${w1:0:1}" == "*" ]
		then
			LN
			exit 0
		fi
	done<<<"$(ntpq -p)"

	if [ $(( $SECONDS - $start_at_s )) -gt $max_seconds ]
	then
		warning "Waiting $(fmt_seconds $(( $SECONDS - $start_at_s )))"
		LN
		info "From $client_hostname execute : ~/plescripts/virtualbox/restart_vboxdrv.sh"
		line_separator
		LN
		exit 1
	fi

	timing $wait_time "Waiting ntp sync"

	case $wait_time in
		10)	wait_time=20
			;;
		20) wait_time=40
			;;
		40)	wait_time=60
			;;
		60) wait_time=10
			;;
	esac
done
