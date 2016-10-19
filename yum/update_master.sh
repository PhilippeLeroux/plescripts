#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

LN
info "Liste des actions effectuées :"
info "	- démarre la VM master ${master_name}"
info "	- se connecte est exécute yum -y update"
info "	- stop la VM master ${master_name}."
LN
confirm_or_exit "Continuer"

exec_cmd start_vm $master_name
[ $? -ne 0 ] && exit 1
exec_cmd wait_server $master_name
[ $? -ne 0 ] && exit 1
exec_cmd "ssh root@${master_name} \"yum makecache; yum -y update\""
LN
exec_cmd stop_vm $master_name
