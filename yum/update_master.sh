#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

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

LN
info "Liste des actions effectuées :"
info "	- démarre la VM master ${master_hostname}"
info "	- se connecte et exécute yum -y update"
info "	- stop la VM master ${master_hostname}."
LN
confirm_or_exit "Continuer"

exec_cmd start_vm $master_hostname
exec_cmd "ssh -t root@${master_hostname} \"plescripts/yum/switch_repo_to.sh -local -release=$orcl_yum_repository_release\""
sleep 1
exec_cmd "ssh -t root@${master_hostname} \"yum makecache; yum -y update\""
LN
exec_cmd stop_vm $master_hostname
