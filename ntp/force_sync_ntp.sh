#!/bin/bash
# vim: ts=4:sw=4

exec >> /tmp/force_sync_ntp.$(date +%d) 2>&1

. ~/plescripts/global.cfg

typeset -r ME=$0

typeset -ri	max_offset_ms=200

#	return abs( $1 )
function abs
{
	typeset	val="$1"
	[ "${val:0:1}" == "-" ] && echo ${val:1} || echo $val
}

#	return integer part of $1
function int_part
{
	cut -d. -f1<<<"$1"
}

#	============================================================================
#	Test si décolage de plus de max_offset_ms
read l_remote l_refid l_st l_t l_when l_pool l_reach l_delay l_offset l_jitter \
													<<<"$(ntpq -p | tail -1)"

offset=$(abs $(int_part $l_offset))
if [ x"$offset" == x ]
then	# Se produit si après démarrage de ntpd on a le message d'erreur :
		# ntpq: read: Connection refused
	echo "offset is null, l_offset = '$l_offset' : bug ???"
	offset=0
fi
[ $offset -lt $max_offset_ms ] && status=OK || status=KO

TT=$(date +%Hh%M)
echo "$TT : abs( ${l_offset} ms ) < ${max_offset_ms} ms : $status"

[ $status == OK ] && exit 0 || true

[ $offset -gt 800 ] && echo "$TT : $l_offset" >> /tmp/ntp_big_offset.$(date +%d) || true

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
	read day month tt l_ntpdate l_ajust l_time l_server ip_ntp_server	\
			l_offset seconds l_sec <<<"$(ntpdate -b $infra_hostname)"

	[ $(abs $(int_part $seconds)) -eq 0 ] && status=OK || status=KO

	echo "Time adjusted #${loop} abs( ${seconds} s ) < 1 s : $status"

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
