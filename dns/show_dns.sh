#!/bin/bash

#	ts=4 sw=4

. ~/plescripts/plelib.sh

info $( fill "~" $(( 18 + 1 + 1 + 1 + 15)) )
info "$(printf "%-18s | %s" "Server" "ip")"
info $( fill "~" $(( 18 + 1 + 1 + 1 + 15)) )

#	Trié par rapport à l'ip node.
cat /var/named/named.orcl	|\
	grep "^[[:alpha:]].*"	|\
	grep -v localhost		|\
	sort -n -t "." -k 4		|\
while read server_name f2 f3 server_ip
do
	info "$(printf "%-18s | %s" $server_name $server_ip)"
done

info $( fill "~" $(( 18 + 1 + 1 + 1 + 15)) )
