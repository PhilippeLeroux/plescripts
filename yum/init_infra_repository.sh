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

if [ "$(hostname -s)" != "$client_hostname" ]
then
	error "Must be executed from $client_hostname"
	LN
	exit 1
fi

typeset -r backup_name="yum_repo.tar.gz"
typeset -r full_backup_name="$iso_olinux_path/$backup_name"

if [ ! -f $full_backup_name ]
then
	line_separator
	info "Cloning OL7 repository on $infra_hostname"
	exec_cmd "ssh -t $infra_conn '~/plescripts/yum/sync_oracle_repository.sh	\
																-force_sync'"
	LN
else	#	Duplication du backup du repo : gain en temps
	line_separator
	exec_cmd "ssh -t $infra_conn \"[ -d /repo ] && rm -rf /repo || true\""
	LN

	info "Copy repository backup to ${infra_conn}"
	exec_cmd scp $full_backup_name ${infra_conn}:/
	LN

	info "Restore OL7 repository on $infra_hostname"
	exec_cmd "ssh -t $infra_conn	\
				'~/plescripts/yum/sync_oracle_repository.sh	\
								-force_sync					\
								-use_tar=/$backup_name'"
fi
