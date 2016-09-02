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

line_separator
info "Clonage du dépôt Oracle Linux sur $infra_hostname"
exec_cmd "ssh $infra_conn '~/plescripts/yum/sync_oracle_repository.sh -copy_iso'"
LN

line_separator
exec_cmd "~/plescripts/shell/start_vm $master_name"
exec_cmd "~/plescripts/shell/wait_server $master_name"
exec_cmd "ssh $master_conn '~/plescripts/yum/disable_net_repository.sh'"
exec_cmd "~/plescripts/shell/stop_vm $master_name"
LN
