#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME retourne la première 'IP node' non utilisée.
	[-range=<#>] Indique le nombre d'IP nodes non utilisées consécutives souhaité.

La première 'IP node' non utilisée sera au minimum 10, les 'IP nodes' inférieur
étant réservées à d'autre usage que des serveurs Oracle.
"

typeset range=1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-range=*)
			range=${1##*=}
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

#	Toutes les IPs en dessous de 10 sont réservées.
typeset	-ri	min_ip_node=10


typeset -i	prev_ip_node=0
typeset	-i	ip_found=0

while read ip_node rem
do
	[ $ip_node -lt $min_ip_node ] && continue

	debug "Last used ip_node == $ip_node, range == $range, prev_ip_node == $prev_ip_node"

	if [ $prev_ip_node -eq 0 ]
	then	# Pas d'IP inférieur utilisée.
		debug -n "Test : ip_node - range -ge min_ip_node == $(( ip_node - range )) -ge $min_ip_node : "
		if [ $(( ip_node - range )) -ge $min_ip_node ]
		then
			debug -f "$OK step 1"
			ip_found=$(( ip_node - 1 ))
			break
		else
			debug -f "$KO"
		fi
	else	# Il faut que l'écart entre les IPs soit gt range
		debug -n "Test : ip_node - prev_ip_node -gt range == $(( ip_node - prev_ip_node )) -gt $range : "
		if [ $(( ip_node - prev_ip_node )) -gt $range ]
		then
			debug -f "$OK step 2"
			ip_found=$(( prev_ip_node + 1 ))
			break
		else
			debug -f "$KO"
		fi
	fi
	prev_ip_node=ip_node
	[ "$DEBUG_FUNC" == enable ] && LN
done<<<"$(cat /var/named/reverse.orcl	|\
				grep "^[0-9]"			|\
				grep -v arpa			|\
				sort -n)"

[ $ip_found -eq 0 ] && ip_found=prev_ip_node+1
#[ $ip_found -lt $min_ip_node ] && ip_found=$min_ip_node

echo $ip_found
