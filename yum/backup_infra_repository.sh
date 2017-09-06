#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

Effectue une sauvegarde locale du dépôt yum de $infra_hostname.
Doit être exécuté sur $client_hostname."

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

must_be_executed_on_server "$client_hostname"

# $1 backup name
function backup_repo_on_infra
{
	info "Create repository backup $1 from $infra_hostname to ~/plescripts/tmp"
	exec_cmd "ssh ${infra_conn} \
				'tar -C /repo -cf - OracleLinux		|\
					gzip -c > ~/plescripts/tmp/$1'"
	LN
}

# $1 full backup name (path + name)
# return 0 OK, else 1 KO
function test_if_backup_valid
{
	info "Validate backup $1"
	exec_cmd "gzip --test '$1'"
	LN
}

typeset -r full_backup_name="$HOME/plescripts/tmp/$backup_repo_name"

[ ! -d "$HOME/plescripts/tmp" ] && exec_cmd "mkdir '$HOME/plescripts/tmp'" || true

if [ -f "$full_backup_name" ]
then
	exec_cmd "ls -l '$full_backup_name'"
	confirm_or_exit "Backup exists. Remove"
	exec_cmd "rm -f '$full_backup_name'"
	LN
fi

backup_repo_on_infra $backup_repo_name

test_if_backup_valid $full_backup_name

info "Bakup [$OK]"
LN
