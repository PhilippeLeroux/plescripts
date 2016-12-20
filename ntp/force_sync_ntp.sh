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

must_be_user root

function abs
{
	typeset	val="$1"
	if [ "${val:0:1}" == "-" ]
	then
		echo ${val:1}
	else
		echo $val
	fi
}

function trunc_decimals
{
	IFS='.' read int_p dec_p<<<"$1"
	echo $int_p
}

function abs_and_trunc_decimals
{
	typeset v=$(abs $1)
	trunc_decimals $v
}

#	return 0 if offset lower than 1000 else 1
function test_offset
{
	exec_cmd ntpq -p
	read l_remote l_refid l_st l_t l_when l_pool l_reach l_delay l_offset l_jitter \
		<<<"$(ntpq -p | tail -1)"

	typeset -i off=$(abs_and_trunc_decimals $l_offset)

	info -n "$off -lt 1000 : "
	if [ $off -lt 1000 ]
	then
		info -f "$OK"
		LN
		return 0
	else
		info -f "$KO"
		LN
		return 1
	fi
}

test_offset
[ $? -eq 0 ] && exit 0 || true

typeset	-r date_before_sync=$(date)
typeset	-r hwclock_before_sync=$(hwclock)

typeset	-r start_at=$SECONDS

exec_cmd systemctl stop ntpd
LN

typeset	-ri	max_loops=50

typeset	-i	loop=0
typeset		time_sync=no

for loop in $( seq $max_loops )
do
	fake_exec_cmd ntpdate -b $infra_hostname
	read day month tt l_ntpdate l_ajust l_time l_server ip_ntp_server	\
			l_offset seconds l_sec <<<"$(ntpdate -b $infra_hostname)"
	echo "$day $month $tt $l_ntpdate $l_ajust $l_time $l_server $ip_ntp_server $l_offset $seconds $l_sec"

	typeset -i secs=$(abs_and_trunc_decimals $seconds)

	info -n "$loop) $secs -eq 0 : "
	if [ $secs -eq 0 ]
	then
		info -f "$OK"
		LN
		time_sync=yes
		break	# exit loop
	else
		info -f "$KO"
		LN
	fi
done

exec_cmd systemctl start ntpd
LN

info "Time to sync        : $(( SECONDS - start_at )) secs"
info "Date before sync    : $date_before_sync"
info "Date after sync     : $(date)"
info "Hwclock before sync : $hwclock_before_sync"
info "Hwclock after sync  : $(hwclock)"
LN

if [ $time_sync == no ]
then
	error "Cannot sync time with $infra_hostname"
	LN
	test_offset
	[ $? -eq 0 ] && exit 0 || exit 1
else
	info "Time sync $OK"
	exit 0
fi
