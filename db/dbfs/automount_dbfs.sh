#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

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

typeset	-r	mount_point=/mnt/dbfs
typeset	-r	pass_file=~/plescripts/db/dbfs/pass

exit_if_dir_not_exists	$mount_point	"$str_usage"
exit_if_file_not_exists	$pass_file		"$str_usage"

nohup mount $mount_point < $pass_file > $HOME/automount.nohup &
cat $HOME/automount.nohup
