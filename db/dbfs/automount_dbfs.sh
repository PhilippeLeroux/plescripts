#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME pdb_name"

script_banner $ME $*

must_be_user oracle

typeset	-r	mount_point=/mnt/$1
typeset	-r	pass_file=~/${1}_pass

exit_if_dir_not_exists	$mount_point	"$str_usage"
exit_if_file_not_exists	$pass_file		"$str_usage"

nohup mount $mount_point < $pass_file > $HOME/automount_${1}.nohup &
cat $HOME/automount_${1}.nohup
exit 0
