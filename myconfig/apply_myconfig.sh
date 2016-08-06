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

info "Apply bashrc extensions :"
exec_cmd cp bashrc_extensions ~/.bashrc_extensions
exec_cmd "sed -i \"/^.*bashrc_extensions.*$/d\" ~/.bashrc"
exec_cmd "echo \"[ -f ~/.bashrc_extensions ] && . ~/.bashrc_extensions || true\" >> ~/.bashrc"
LN

info "[G]vim configuration :"
exec_cmd cp myvimrc ~/.vimrc
exec_cmd cp vimtips ~/.vimtips
LN

info "tmux configuration :"
exec_cmd cp mytmux.conf ~/.tmux.conf
LN

info "Positionne les acls sur ~/plescripts"
# Pour supprimer les acls : setfacl -Rb ~/plescripts/
exec_cmd -c setfacl -Rm d:g:users:rwx $HOME/plescripts
if [ $? -ne 0 ]
then
	info "with root exec : setfacl -Rm d:g:users:rwx $HOME/plescripts"
fi
LN
