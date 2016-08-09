#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "Running : $ME $*"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOOP
			first_args=-emul
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

typeset -r targetcli_path=~/plescripts/san/targetcli_backup
if [ ! -d $targetcli_path ]
then
	error "Directory $targetcli_path not exists !"
	exit 1
fi

info "Supprime les sauvegardes de plus de 7 jours."
exec_cmd "find $targetcli_path/* -mtime -7 -exec rm {} \;"
LN
