#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh

typeset	-r	domain=$(hostname -d)

typeset	-r	horizontal_separator=$( fill "~" $(( 18 + 1 + 1 + 1 + 15)) )
info $horizontal_separator
info "$(printf "%-18s | %s" "Server" "ip")"
info $horizontal_separator

# Avec le DHCP les fichiers DNS sont reformatés, les IP d'une adresse de SCAN
# ne sont pas simple à récupérer, donc je passe maintenant par le fichier
# reverse.
typeset	-r	network="$(ping -c 1 $(hostname)	|\
							grep "PING"			|\
							cut -d\( -f2		|\
							cut -d. -f1-3)"
cat /var/named/reverse.$domain	|\
		grep -E "^[0-9]"		|\
		grep -v "arpa"			|\
		sort -n					|\
while read ip_node f2 server_name
do
	[ x"$ip_node" == x ] && continue || true
	server_name="$(cut -d. -f1<<<"$server_name")"
	info "$(printf "%-18s | %s" $server_name "$network.$ip_node")"
done

info $horizontal_separator
