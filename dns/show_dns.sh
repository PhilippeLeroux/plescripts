#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh

typeset -r	domain=$(hostname -d)

typeset	-r	horizontal_separator=$( fill "~" $(( 18 + 1 + 1 + 1 + 15)) )
info $horizontal_separator
info "$(printf "%-18s | %s" "Server" "ip")"
info $horizontal_separator

#	Trié par rapport à l'ip node.
cat /var/named/named.$domain		|\
	grep -E "^[[:alpha:]].*\sA\s."	|\
	grep -v localhost				|\
	sort -n -t "." -k 4				|\
while read server_name f1 f2 server_ip
do
	# Avec l'enregistrement DHCP il y a un champ de moins.
	[ x"$server_ip" == x ] && server_ip=$f2 || true
	info "$(printf "%-18s | %s" $server_name $server_ip)"
done

info $horizontal_separator
