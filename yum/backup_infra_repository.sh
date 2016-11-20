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
	error "must be executed from $client_hostname."
	exit 1
fi

typeset -r backup_name="yum_repo.tar.gz"
typeset -r full_backup_name="$iso_olinux_path/$backup_name"
[ -f "$full_backup_name" ] && confirm_or_exit "Backup exit. Remove"

exec_cmd "ssh ${infra_conn} \"cd /repo; tar cf - ol7 | gzip -c > $backup_name\""
exec_cmd "scp ${infra_conn}:/repo/$backup_name $full_backup_name"
exec_cmd "ssh ${infra_conn} \"rm -rf /repo/$backup_name\""
LN
