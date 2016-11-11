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

if [ ! -f $iso_olinux_path/yum_repo.tar ]
then
	line_separator
	info "Cloning OL7 repository on $infra_hostname"
	exec_cmd "ssh -t $infra_conn '~/plescripts/yum/sync_oracle_repository.sh	\
																-force_sync'"
	LN
else	#	Duplication du backup du repo : gain en temps
	line_separator
	info "Copy repository backup to ${infra_conn}"
	exec_cmd scp $iso_olinux_path/yum_repo.tar ${infra_conn}:/
	LN

	info "Cloning OL7 repository on $infra_hostname"
	exec_cmd "ssh -t $infra_conn	\
				'~/plescripts/yum/sync_oracle_repository.sh	\
								-force_sync					\
								-use_tar=/yum_repo.tar'"
fi
