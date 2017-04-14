#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset infra_install=no

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

		-infra_install)
			# Active la log et paramètre passé au script sync_oracle_repository.sh
			infra_install=yes
			pass_arg="-infra_install"
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

[ $infra_install == no ] && ple_enable_log || true

script_banner $ME $*

must_be_executed_on_server "$client_hostname"

typeset -r full_backup_name="$HOME/plescripts/tmp/$backup_repo_name"

if [[ $infra_install == yes && ${infra_yum_repository_release:0:3} == DVD ]]
then
	line_separator
	exec_cmd "~/plescripts/yum/create_repo_from_dvd.sh	\
									-release=$infra_yum_repository_release"
elif [ ! -f $full_backup_name ]
then # Pas de backup de dépôt, la synchronisation sera longue.
	line_separator
	info "Cloning OL7 repository on $infra_hostname"
	exec_cmd "ssh -t root@$infra_ip	\
			'~/plescripts/yum/sync_oracle_repository.sh $pass_arg'"
	LN
else # Le dépôt sera initialisé avec $full_backup_name
	line_separator
	exec_cmd "ssh -t root@$infra_ip \"[ -d /repo ] && rm -rf /repo || true\""
	LN

	info "Restore OL7 repository on $infra_hostname"
	exec_cmd "ssh -t root@$infra_ip	\
				'~/plescripts/yum/sync_oracle_repository.sh	\
					-use_tar=\"\$HOME/plescripts/tmp/$backup_repo_name\" $pass_arg'"
	LN
fi
