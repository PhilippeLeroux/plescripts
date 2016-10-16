#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -backup|-restore"

script_banner $ME $*

typeset action=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-backup)
			action=backup
			shift
			;;

		-restore)
			action=restore
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

exit_if_param_invalid action "backup restore" "$str_usage"

case $action in
	backup)
		exec_cmd cp ~/.vimrc ~/plescripts/myconfig/vimrc
		LN

		exec_cmd rm ~/plescripts/myconfig/vimfunc.tar.gz
		LN

		exec_cmd "tar -cf - -C $HOME/ vimfunc | gzip -c > ~/plescripts/myconfig/vimfunc.tar.gz"
		LN
		;;

	restore)
		exec_cmd cp ~/plescripts/myconfig/vimrc ~/.vimrc
		LN

		exec_cmd "gzip -dc ~/plescripts/myconfig/vimfunc.tar.gz | tar xf - -C $HOME/"
		;;
esac
