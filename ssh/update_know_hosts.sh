#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME

Si l'adresse IP d'un serveur change, le nom du serveur correspondant est
supprimé du fichier know_hosts.

Le script ajoute le nom, pour facilement identifier le serveur correspondant.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

#ple_enable_log -params $PARAMS

typeset	-i	nr_updates=0
while read ip rem
do
	[ x"$ip" == x ] && continue || true
	host=$(cut -d\. -f1<<<"$(cut -d\  -f5<<<"$(host $ip)")")
	[ x"$host" == x ] && continue || true
	sed -i "s/^$ip\(.*\)/$host,$ip\1/" ~/.ssh/known_hosts
	info "$ip <=> $host updated."
	((++nr_updates))
	LN
done<<<"$(grep -E "^[0-9]" ~/.ssh/known_hosts)"

info "$nr_updates IP updated."
LN
