#!/bin/bash

# vim: ts=4:sw=4

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME <IP node>
	retourne 1 si 'IP node' est utilisée, 0 sinon.

Le réseau utilise le mask 255.255.255.
'IP node' correspond au dernier n° de l'adresse IP.
"

case $1 in
	-h|-help|help)
		echo "$str_usage"
		exit 1
	;;
esac

typeset -r	domain=$(hostname -d)

cat /var/named/named.$domain | grep -Eq "^[a-z].*\.$1$"
[ $? -eq 0 ] && exit 1 || exit 0
