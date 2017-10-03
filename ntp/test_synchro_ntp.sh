#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset	-i	max_loops=10

typeset -r	str_usage=\
"Usage :
	$ME [-max_loops=$max_loops]"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-max_loops=*)
			max_loops=${1##*=}
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

typeset -r	hn=$(hostname -s)
typeset	-i	wait_time=10

LN
line_separator
info "If synchronization take a long time use Ctrl+C to stop it."
info "From $client_hostname execute : ~/plescripts/virtualbox/restart_vboxdrv.sh"
line_separator
LN

for (( iloop=0; iloop <= max_loops; ++iloop ))
do
	[ $iloop -ne 0 ] && timing $wait_time "Waiting ntp sync" || true

	while read w1 w2 rem
	do
		[[ "$w2" == "" || "$w1" == "remote" ]] && continue || true

		info "$hn sync state : $w1"
		[ "${w1:0:1}" == "*" ] && exit 0 || true
	done<<<"$(ntpq -p)"

	case $wait_time in
		10)	[ $iloop -ne 0 ] && wait_time=20 || true
			;;
		20) wait_time=40
			;;
		40)	wait_time=60
			;;
		60) wait_time=10
			;;
	esac
done

error "Sync failed !"
exit 1
