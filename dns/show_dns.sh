#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

typeset	-r	horizontal_separator=$( fill "~" $(( 18 + 1 + 1 + 1 + 15 )) )

info $horizontal_separator
info "$(printf "%-18s | %s" "Server" "IP")"
info $horizontal_separator

typeset		prev_server_name
typeset		ip_type=reserved

cat /var/named/reverse.$infra_domain	|\
		grep -E "^[0-9]"				|\
		grep -v "arpa"					|\
		sort -n							|\
while read ip_node f2 server_name
do
	[ x"$ip_node" == x ] && continue || true

	case "$ip_type" in
		reserved)
			if [ "$ip_node" -gt "$dhcp_max_ip_node" ]
			then # Toutes les IP réservées ont été affichée et il n'y a pas d'IP dynamiques.
				info $horizontal_separator
				ip_type=orcl_servers
			elif [ "$ip_node" -ge "$dhcp_min_ip_node" ]
			then # Toutes les IP réservées ont été affichées.
				info $horizontal_separator
				ip_type=dynamic
			fi
			;;
		dynamic)
			if [ "$ip_node" -gt "$dhcp_max_ip_node" ]
			then # Toutes les IP dynamiques ont été affichées.
				info $horizontal_separator
				ip_type=orcl_servers
			fi
			;;
	esac

	# Supprime le nom de domaine.
	server_name="$(cut -d. -f1<<<"$server_name")"

	if [ "$prev_server_name" == "$server_name" ]
	then # Les adresses de SCAN ne sont affichées qu'une fois.
		server_name=""
	else
		prev_server_name=$server_name
	fi
	info "$(printf "%-18s | %s" "$server_name" "$infra_network.$ip_node")"
done

info $horizontal_separator
