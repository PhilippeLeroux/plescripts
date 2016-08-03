#!/bin/bash

#	ts=4 sw=4

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

typeset -i	prev_ip_node=0
typeset	-i	ip_found=0

while read ip_node rem
do
	if [ $ip_node -gt 9 ]
	then
		if [ $ip_node -gt $(( prev_ip_node + 2 )) ]
		then
			if [ $(( prev_ip_node + range )) -lt $ip_node ]
			then
				ip_found=$prev_ip_node+1
				break
			fi
		fi
	fi
	prev_ip_node=ip_node
done<<<"$(cat /var/named/reverse.orcl	|\
				grep "^[0-9]"			|\
				grep -v arpa			|\
				sort -n)"

[ $ip_found -eq 0  ] && ip_found=prev_ip_node+1
[ $ip_found -lt 9  ] && ip_found=10

echo $ip_found
