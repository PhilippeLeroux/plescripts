#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME [-emul]"

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

line_separator
info "Apply bashrc extensions :"
exec_cmd cp bashrc_extensions ~/.bashrc_extensions
exec_cmd "sed -i \"/^.*bashrc_extensions.*$/d\" ~/.bashrc"
exec_cmd "echo \"[ -f ~/.bashrc_extensions ] && . ~/.bashrc_extensions || true\" >> ~/.bashrc"
LN

line_separator
info "[G]vim configuration :"
exec_cmd "~/plescripts/myconfig/vim_config.sh -restore"
LN

line_separator
info "tmux configuration :"
exec_cmd cp mytmux.conf ~/.tmux.conf
LN

line_separator
exec_cmd -c "~/plescripts/shell/set_plescripts_acl.sh"
LN
