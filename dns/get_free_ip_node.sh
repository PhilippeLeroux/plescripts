#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

#	Toutes les IPs en dessous sont réservées.
typeset	-ri	min_ip_node=dhcp_max_ip_node+1

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME retourne la première 'IP node' non utilisée.
	[-range=<#>] Indique le nombre d'IP nodes non utilisées consécutives souhaité.

La première 'IP node' non utilisée sera au minimum $min_ip_node, les 'IP nodes'
inférieur étant réservées à d'autres usages que des serveurs Oracle.
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

typeset	-r	domain=$(hostname -d)
typeset -i	prev_ip_node=0
typeset	-i	ip_found=0

while read ip_node rem
do
	[[ x"$ip_node" == x || $ip_node -lt $min_ip_node ]] && continue

	debug "IP used is $ip_node"
	if [ $prev_ip_node -eq 0 ]
	then	# On vient de lire la première IP, vérifie si min_ip_node est utilisée.
		debug "Case 1 : First IP found is ip_node($ip_node)"
		if [ $ip_node -gt $min_ip_node ]
		then
			debug "\tTest if ip_node($ip_node) - min_ip_nod($min_ip_node) >= range($range) :"
			if [ $(( ip_node - min_ip_node )) -ge $range ]
			then
				debug "\t\t$OK min_ip_node($min_ip_node) unused"
				ip_found=$min_ip_node
				break	# exit while
			else
				debug "\t\t$KO continue."
			fi
		else
			debug "\tcontinue min_ip_node($min_ip_node) is used."
		fi
	else
		debug "Case 2 : prev_ip_node == $prev_ip_node, ip_node == $ip_node"
		debug "\tTest if ip_node($ip_node) - prev_ip_node($prev_ip_node) > range($range) :"
		if [ $(( ip_node - prev_ip_node )) -gt $range ]
		then
			debug "\t\t$OK ip_found = $ip_node - $range"
			ip_found=$(( ip_node - range ))
			break	# exit while
		else
			debug "\t\t$KO do nothing."
		fi
	fi

	prev_ip_node=$ip_node

	[ "$DEBUG_MODE" == ENABLE ] && LN
done<<<"$(cat /var/named/reverse.$domain	|\
				grep "^[0-9]"				|\
				grep -v arpa				|\
				sort -n)"

[ "$DEBUG_MODE" == ENABLE ] && LN

debug "ip_found     = $ip_found"
debug "prev_ip_node = $prev_ip_node"

if [ $prev_ip_node -eq 0 ]
then #	Si prev_ip_node == 0 alors il n'y a pas d'IPs utilisées à partir de min_ip_node
	ip_found=$min_ip_node
elif [ $ip_found -eq 0 ]
then #	Si ip_found == 0 alors pas d'IP trouvée, on prend donc la dernière IP + 1
	ip_found=prev_ip_node+1
fi

debug "IPs free : [$ip_found,$(( ip_found + range - 1 ))] range of $range IPs."
debug "return $ip_found"
echo $ip_found
