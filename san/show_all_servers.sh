#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

targetcli ls iscsi							|\
	grep -E "iqn.[0-9]{4}-[0-9]{2}.com"		|\
	sed "s/.*\(iqn.*[0-9]\) .*/\1/g"		|\
	sort | uniq | cut -d. -f4				|\
	sed "s/://g"							|\
while read server_name
do
	info "$server_name"
	exec_cmd "targetcli ls @$server_name"
	LN
done

