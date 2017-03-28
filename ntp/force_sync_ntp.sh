#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/global.cfg

typeset -r ME=$0

typeset -ri	max_offset_ms=1

#	print abs( $1 ) to stdout
function abs
{
	typeset	val="$1"
	[ "${val:0:1}" == "-" ] && echo ${val:1} || echo $val
}

#	print integer part of $1 to stdout
function int_part
{
	cut -d. -f1<<<"$1"
}

# print offset in ms to stdout
function ntpq_read_offset_ms
{
	read	l_remote l_refid l_st l_t l_when l_pool	\
			l_reach l_delay l_offset l_jitter		\
		<<<"$(ntpq -p | tail -1)"
	abs $(int_part $l_offset)
}

# print offset in ms to stdout
function ntpdate_read_offset_ms
{
	typeset seconds
	read day month tt l_ntpdate l_ajust l_time l_server ip_ntp_server	\
			l_offset seconds l_sec <<<"$(ntpdate -b $infra_hostname)"

	if [ $(abs $(int_part $seconds)) -gt 0 ]
	then
		echo "1000"
	else
		sed "s/.*\.\(...\).*/\1/"<<<"$seconds"
	fi
}

#	============================================================================
#	Test si décalage de plus de max_offset_ms
typeset -i offset_ms=10#$(ntpq_read_offset_ms)
[ $offset_ms -lt $max_offset_ms ] && status=OK || status=KO

[ $status == OK ] && exit 0 || true

[ ! -t 1 ] && exec >> /tmp/force_sync_ntp.$(date +%d) 2>&1 || true

TT=$(date +%Hh%M)
echo "$TT : $offset_ms ms < $max_offset_ms ms : $status"

typeset -r lockfile=/var/lock/force_sync_ntp.lock
[[ -f $lockfile ]] && exit 0 || true
trap "{ rm -f $lockfile ; exit 0; }" EXIT
touch $lockfile

#	============================================================================
typeset	-r date_before_sync=$(date)
typeset	-r start_at=$SECONDS

#	============================================================================
echo "systemctl stop ntpd"
systemctl stop ntpd

#	============================================================================
typeset	-ri	max_loops=4	# sécurité au cas ou la synchro ne se fait pas.

typeset	-i	loop=0
typeset		time_sync=no

for loop in $( seq $max_loops )
do
	typeset -i offset_ms=10#$(ntpdate_read_offset_ms)
	[ $offset_ms -lt $max_offset_ms ] && status=OK || status=KO

	echo "Time adjusted #${loop} $offset_ms ms  < $max_offset_ms ms : $status"

	[ $status == OK ] && time_sync=yes && break	# exit loop
done

#	============================================================================
echo "systemctl start ntpd"
systemctl start ntpd

#	============================================================================
echo "Synchronization time : $(( SECONDS - start_at )) secs"
echo "Date before sync     : $date_before_sync"
echo "Date after sync      : $(date)"
echo
[ $time_sync == yes ] && exit 0 || exit 1
