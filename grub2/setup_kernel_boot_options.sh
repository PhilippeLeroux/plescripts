#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"
typeset	-r	str_usage=\
"Usage :
$ME
	[-add=\"param1 param2\"]
	[-remove=\"param1 param2\"]
	[-show]
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

		-show)
			action=show
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

function show_boot_options
{
	info "Boot options :"
	exec_cmd "grep 'vmlinuz-$(uname -r)' /etc/grub2.cfg|cut -d\  -f3-"
	LN
}

if [[ "$params" == undef && $action != show ]]
then
	error "no parameter for action $action"
	LN
	info "$str_usage"
	LN
	exit 1
fi

must_be_user root

if [ $action != show ]
then
	info "Modify kernel parameter, $action parameters \"$params\""
	LN

	line_separator
	info "Backup /etc/grub2.cfg"
	exec_cmd cp /etc/grub2.cfg /etc/grub2.cfg.$(date +%y%m%d_%H%M)
	LN

	line_separator
fi

case $action in
	remove)
		exec_cmd "grubby --update-kernel=ALL --remove-args=\"$params\""
		LN
		show_boot_options
		;;
	add)
		exec_cmd "grubby --update-kernel=ALL --args=\"$params\""
		LN
		show_boot_options
		;;
	show)
		show_boot_options
		;;
	*)
		error "Action '$action' invalid."
		LN
		info "$str_usage"
		LN
		exit 1
		;;
esac
