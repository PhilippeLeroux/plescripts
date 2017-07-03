#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -i pause=10

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME [-pause=$pause] seconds

Affiche à interval régulier la synchronisation du démon ntp"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-pause=*)
			pause=${1##*=}
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

while [ true ]
do
	header="$(hostname -s) : $(date "+%Hh%Mmn%Ss") (next in ${pause}s)"
	buffer="$(ntpq -p)"
	last_line="$(tail -1<<<"$buffer")"
	if [ "${last_line:0:1}" == "*" ]
	then
		echo "SYNC OK $header"
	else
		echo "SYNC KO $header"
	fi
	echo "$buffer"
	echo
	sleep $pause
done
