#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
$ME
	[-add=\"param1 param2=val\"]
	[-remove=\"param1 param2=val\"]
"

typeset action=none	# add or remove
typeset params=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-add=*)
			action=add
			params="${1#*=}"
			shift
			;;

		-remove=*)
			action=remove
			params="${1#*=}"
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

if [ "$params" == undef ]
then
	error "no parameter for action $action"
	LN
	info "$str_usage"
	LN
	exit 1
fi

must_be_user root

info "Modify kernel parameter, $action parameters \"$params\""
LN

line_separator
info "Backup /etc/default/grub"
exec_cmd cp /etc/default/grub /etc/default/grub.$(date +%d%m%y%H%M)
LN

line_separator
case $action in
	remove)
		exec_cmd "grubby --update-kernel=ALL --remove-args=\"$params\""
		LN
		;;

	add)
		exec_cmd "grubby --update-kernel=ALL --args=\"$params\""
		LN
		;;
esac
