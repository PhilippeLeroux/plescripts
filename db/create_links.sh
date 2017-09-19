#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME -db=name"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_upper ${1##*=})
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

must_be_user oracle

exit_if_param_undef db	"$str_usage"

typeset -r	admin_dir=$ORACLE_BASE/admin/$db

exit_if_dir_not_exists $admin_dir

if [ ! -L $HOME/$db ]
then
	info "Create link on $admin_dir to $HOME"
	exec_cmd ln -s $admin_dir $HOME/$db
	LN
fi

if [ ! -d $admin_dir/log ]
then
	info "Create directory log to $admin_dir"
	exec_cmd mkdir $admin_dir/log
	LN
fi

if [ ! -L $HOME/log ]
then
	info "Create link on $admin_dir/log to $HOME"
	exec_cmd ln -s $admin_dir/log $HOME/log
	LN
fi
