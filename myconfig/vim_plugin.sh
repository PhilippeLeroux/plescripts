#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r plugin_list=~/plescripts/myconfig/vim_plugin_list.txt

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-url=<url>         : Installe depuis l'url github un plugin.
	-show              : Affiche l'ensemble des plugins installés.
	-del=<plugin name> : Supprime un plugin.
	-init              : Réinitialise tous les plugins.

Pour l'initialisation (-init) les plugins à installer sont lues dans le fichier :
	$plugin_list
"

typeset url=undef
typeset action=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-init)
			action=init
			shift
			;;

		-url=*)
			url=${1##*=}
			action=install_plugin
			shift
			;;

		-show)
			action=show
			shift
			;;

		-del=*)
			plugin_name=${1##*=}
			action=uninstall_plugin
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

function exit_if_pathogen_not_installed
{
	if [ ! -f ~/.vim/autoload/pathogen.vim ]
	then
		error "Pathogen not installed."
		error "$ME -init to install all plugins"
		exit 1
	fi
}

function backup_and_remove_tod_vim
{
	typeset -r backup="~/vim_$(date +"%Y%m%d_%Hh%M")"

	if [ -d ~/.vim ]
	then
		info "Backup ~/.vim to $backup"
		exec_cmd "mv ~/.vim $backup"
		LN
	fi

	exec_cmd "mkdir -p ~/.vim/autoload"
	LN
}

# Variable languageToolDirectory must exists.
function directory_LanguageTool_exists
{
	if [ ! -v languageToolDirectory ]
	then
		error "Variable languageToolDirectory not declared."
		LN
		exit 1
	fi

	typeset -a path_list=( $(find ~/ -maxdepth 1 -type d -name "LanguageTool*"|tr '\n' ' ') )

	case ${#path_list[*]} in
		0)
			warning "No path ~/LanguageTool* found."
			LN
			return 1
			;;
		1)
			languageToolDirectory=${path_list##*/}
			return 0
			;;
		*)
			warning "${#path_list[*]} paths ~/LanguageTool* found."
			LN
			return 1
			;;
	esac
}

function install_plugin
{
	# Supprime https: ou git: s'ils sont précisés eau début de l'URL.
	typeset url=${1#https:}
	url=${url#git:}

	# Lecture du nom du plugin.
	typeset	name=${url##*/}
	name=${name%.git}

	info "git  : git:$url"
	info "name : $name"
	LN

	exec_cmd "cd ~/.vim && git submodule add git:$url bundle/$name"
	exec_cmd "cd ~/.vim && git submodule init && git submodule update"
	LN

	# Particularité pour chaque plugin.
	case "$name" in
		"vim-grammarous")
			typeset languageToolDirectory=undef
			if directory_LanguageTool_exists
			then
				exec_cmd "mkdir ~/.vim/bundle/vim-grammarous/misc"
				exec_cmd "ln -s ~/$languageToolDirectory ~/.vim/bundle/vim-grammarous/misc/$languageToolDirectory"
				LN
			fi
			;;
	esac
}

function uninstall_plugin
{
	typeset -r plugin_name=$1

	exec_cmd "cd ~/.vim && git submodule deinit -f  bundle/$plugin_name"
	exec_cmd "cd ~/.vim && git rm -f  bundle/$plugin_name"
	exec_cmd "rm -rf ~/.vim/.git/modules/bundle/$plugin_name"
	LN
}

function install_pathogen
{
	info "Install Pathogen"
	exec_cmd "cd ~/ && git clone git://github.com/tpope/vim-pathogen.git pathogen"
	exec_cmd "mv ~/pathogen/autoload/* ~/.vim/autoload/"
	exec_cmd "rm -rf ~/pathogen"
	LN

	info "Init Pathogen"
	exec_cmd "cd .vim && git init && git add  . && git commit -m \"Initial commit\""
	LN

	grep "pathogen#infect" ~/.vimrc >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
		info "Update ~/.vimrc"
		exec_cmd "sed -i \"1i\\call pathogen#infect()\" ~/.vimrc"
		exec_cmd "sed -i \"2i\\call pathogen#helptags()\" ~/.vimrc"
		LN
	fi
}

function install_all
{
	exit_if_file_not_exists $plugin_list

	backup_and_remove_tod_vim

	install_pathogen

	while read line
	do
		case ${line:0:1} in
			'#')
				info "${line:1}"
				LN
				;;

			'/'|'h')
				install_plugin $line
				;;

			'')
				LN
				;;

			*)
				warning "'${line:0:1}' : $line"
				LN
				;;
		esac
	done<<<"$( cat $plugin_list )"
}

#	======================================================================
#	MAIN
#	======================================================================

case $action in
	init)
		install_all
		exec_cmd "cd ~/.vim && git status"
		LN

		exec_cmd "mkdir ~/.vim/spell"
		exec_cmd "cd ~/.vim/spell/; wget http://ftp.vim.org/vim/runtime/spell/fr.utf-8.spl"
		exec_cmd "cd ~/.vim/spell/; wget http://ftp.vim.org/vim/runtime/spell/fr.utf-8.sug"
		LN
		;;

	show)
		exec_cmd "cd ~/.vim && git submodule"
		LN
		;;

	install_plugin)
		exit_if_pathogen_not_installed
		install_plugin $url
		exec_cmd "cd ~/.vim && git status"
		LN
		;;

	uninstall_plugin)
		uninstall_plugin $plugin_name
		exec_cmd "cd ~/.vim && git status"
		LN
		;;

	undef)
		info "$str_usage"
		LN
		exit 1
		;;
	*)
		error "Unknow action $action"
		LN
		info "$str_usage"
		LN
		exit 1
esac
