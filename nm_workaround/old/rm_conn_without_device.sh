#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME ...."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

while read name uuid type device
do
	if [ x"$name" != x ]
	then
		info "Remove '$name' no device associate : '$device'"
		exec_cmd "nmcli connection delete uuid \"$uuid\""
		LN
	fi
done<<<"$(nmcli -p con show | grep -E "^eth.*--\s*$")"
