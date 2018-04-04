#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -backup|-restore"

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
		info "Supprime les anciens backups."
		exec_cmd rm -f ~/plescripts/myconfig/vimfunc.tar.gz
		exec_cmd rm -f ~/plescripts/myconfig/vim.tar.gz
		LN

		info "Backup le répertoire des fonctions : ~/vimfunc"
		exec_cmd "tar -cf - -C $HOME/ vimfunc | gzip -c > ~/plescripts/myconfig/vimfunc.tar.gz"
		LN

		info "Backup ~/.vim/.gitmodules qui est exclue de vim.tar.gz"
		exec_cmd "cp ~/.vim/.gitmodules ~/plescripts/myconfig/gitmodules"
		LN

		info "Backup le répertoire .vim"
		exec_cmd "tar --exclude '.git*' -C $HOME -cf - .vim  	|\
					gzip -c > ~/plescripts/myconfig/vim.tar.gz"
		LN
		;;

	restore)
		if [ ! -h  ~/.vimrc ]
		then
			if [ -f ~/.vimrc ]
			then
				info "Backup ~/.vimrc to ~/vimrc.backup"
				exec_cmd "mv ~/.vimrc ~/vimrc.backup"
				LN
			fi

			info "Create symlink"
			exec_cmd "ln -s ~/plescripts/myconfig/vimrc ~/.vimrc"
			LN
		fi

		info "Restaure le répertoire des fonctions"
		exec_cmd "rm -rf $HOME/vimfunc"
		exec_cmd "gzip -dc ~/plescripts/myconfig/vimfunc.tar.gz | tar xf - -C $HOME/"
		LN

		info "Restaure les plugins"
		exec_cmd "rm -rf $HOME/.vim"
		exec_cmd "gzip -dc ~/plescripts/myconfig/vim.tar.gz | tar xf - -C $HOME/"
		exec_cmd "rm -rf $HOME/.vim/sessions"
		exec_cmd "cp ~/plescripts/myconfig/gitmodules ~/.vim/.gitmodules"
		LN
		;;
esac
