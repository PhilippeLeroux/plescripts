#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

typeset -r ignore_file=~/plescripts/.gitignore

function add_dir
{
	typeset -r dir_name=$1

	info "ignore '$dir_name'"
	exec_cmd "echo $dir_name >> $ignore_file"
	LN
}

info "Efface tous les répertoires database_servers/...."
exec_cmd "sed -i '/^database_servers\//d' .gitignore"
LN

cmd_find="find ~/plescripts/database_servers/* -type d"
fake_exec_cmd $cmd_find
eval "$cmd_find" |\
while read dir_name
do
	case ${dir_name##*/} in
		screen)
			: # skeep
			;;

		*)
			add_dir ${dir_name#/*/*/*/}
			;;
	esac
done

exec_cmd "git commit $ignore_file -m \"Mise à jour de .gitignore\""
