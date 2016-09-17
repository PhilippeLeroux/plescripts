#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset scan_name=$1
[ x"$scan_name" == x ] && scan_name=$(olsnodes -c 2>/dev/null)
[ x"$scan_name" == x ] && error "$ME <scan-adress>" && exit 1

exec_cmd -ci "systemctl status nscd.service 2>/dev/null 1>&2"
if [ $? -eq 0 ]
then
	LN
	line_separator
	warning "La cache DNS est actif, seul une IP de l'adresse de SCAN sera donc utilisée"
	line_separator
fi
LN

typeset -a	ip_list

line_separator
info "Ping $scan_name"
for i in $( seq 1 3 )
do
	info -n "    ping #${i} "
	ip_list[$((i-1))]=$(ping -c 1 $scan_name | head -2 | tail -1 | sed "s/.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)).*/\1/")
	timing 1
done

# $1 indice de l'IP dans ip_list
function test_ip_uniq
{
	typeset -ri indice=$1

	typeset -i count_diffs=0
	typeset -i i=0
	while [ $i -lt ${#ip_list[@]} ]
	do
		if [ $i -ne $indice ]
		then
			[ "${ip_list[$i]}" != "${ip_list[$indice]}" ] && count_diffs=count_diffs+1
		fi
		i=i+1
	done

	[ $count_diffs -eq 2 ] && return 0 || return 1
}

info "Nombre d'IPs : ${#ip_list[@]}"
typeset	-i	dup=0
typeset -i	i=0
while [ $i -lt ${#ip_list[@]} ]
do
	info -n "IP $(( i + 1 )) : ${ip_list[$i]}"
	test_ip_uniq $i
	if [ $? -ne 0 ]
	then
		info -f " : dupliquée."
		dup=dup+1
	else
		LN
	fi
	i=i+1
done
LN

info "$dup ping sur la même IP"
LN

[ $dup -eq 3 ] && warning "Cache DNS actif ?" && LN


line_separator
exec_cmd nslookup $scan_name
exec_cmd host $scan_name
LN

info "On RAC node : cluvfy comp scan"
