#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME 
Affiche l'IP internet"

while [ $# -ne 0 ]
do
	case $1 in
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

exec_cmd "wget http://checkip.dyndns.org/	--output-document -		\
											--output-file /dev/null	|\
											sed 's/.*Address: \([0-9].*[0-9]\).*$/\1/'"
