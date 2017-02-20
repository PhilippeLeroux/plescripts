#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME

Initialise le dépôt yum sur le serveur $infra_hostname.
Doit être exécuté depuis $client_hostname."

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

ple_enable_log

script_banner $ME $*

must_be_executed_on_server "$client_hostname"

typeset -r backup_name="yum_repo.tar.gz"
typeset -r full_backup_name="$iso_olinux_path/$backup_name"

if [ ! -f $full_backup_name ]
then # Pas de backup de dépôt, la synchronisation sera longue.
	line_separator
	info "Cloning OL7 repository on $infra_hostname"
	exec_cmd "ssh -t root@$infra_ip '~/plescripts/yum/sync_oracle_repository.sh'"
	LN
else # Le dépôt sera initialisé avec $full_backup_name
	line_separator
	exec_cmd "ssh -t root@$infra_ip \"[ -d /repo ] && rm -rf /repo || true\""
	LN

	info "Copy repository backup to ${infra_ip}"
	exec_cmd scp $full_backup_name root@${infra_ip}:/
	LN

	info "Restore OL7 repository on $infra_hostname"
	exec_cmd "ssh -t root@$infra_ip	\
				'~/plescripts/yum/sync_oracle_repository.sh	\
								-use_tar=/$backup_name'"
fi
