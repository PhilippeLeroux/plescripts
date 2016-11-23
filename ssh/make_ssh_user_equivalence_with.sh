#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -user=<> -server=<>"

typeset user=undef
typeset server=undef

while [ $# -ne 0 ]
do
	case $1 in
		-server=*)
			server=${1##*=}
			shift
			;;

		-user=*)
			user=${1##*=}
			shift
			;;

		*)
			error "'$1' invalid."
			LN
			info $str_usage
			LN
			exit 1
	esac
done

exit_if_param_undef user	$str_usage
exit_if_param_undef server	$str_usage

add_2_know_hosts $server
LN

typeset -r current_host=$(hostname -s)

info "ssh connection $USER@$current_host / $user@$server"
if [ ! -f ~/.ssh/id_rsa.pub ]
then
	info "Génération des clefs pour $USER@$current_host"
	exec_cmd "ssh-keygen -t rsa -N \"\" -f ~/.ssh/id_rsa"
fi
LN

info "Copy de la clef public sur ${user}@${server}"
exec_cmd "ssh-copy-id -i ~/.ssh/id_rsa.pub ${user}@${server}"
LN
