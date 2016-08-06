#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -name=<str>"

typeset name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-name=*)
			name=${1##*=}
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

exit_if_param_undef name	"$str_usage"

typeset -r targetcli_path=~/plescripts/san/targetcli_backup

if [ ! -d $targetcli_path ]
then
	exec_cmd "mkdir $targetcli_path"
fi

typeset -r targetcli_file=${targetcli_path}/$(date +"%Y%m%d_%Hh%Mmn%S")_${name}.json

info "Backup file : $targetcli_file"
exec_cmd "targetcli / saveconfig $targetcli_file"
exec_cmd "targetcli / saveconfig"
