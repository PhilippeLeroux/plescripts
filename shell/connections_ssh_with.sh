#!/bin/bash

#	ts=4 sw=4

#	ts=4 sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -user=<> -server=<>"

user=undef
server=undef

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

typeset -r current_host=$(hostname -s)

function update_know_hosts
{
	typeset -r server_name=$1

	info "Supprime $server_name du fichier ~/.ssh/known_hosts"
	exec_cmd -c "sed -i '/^$server_name.*/d' ~/.ssh/known_hosts 1>/dev/null"
	LN

	info "Ajoute la clef de $server_name dans  ~/.ssh/known_hosts"
	remote_keyscan=$(ssh-keyscan -t ecdsa $server_name | tail -1)
	exec_cmd "echo \"$remote_keyscan\" >> ~/.ssh/known_hosts"
}

update_know_hosts $server
LN

info "ssh connection $USER@$current_host / $user@$server"
if [ ! -f ~/.ssh/id_rsa.pub ]
then
	info "Génération des clefs"
	exec_cmd "[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -N \"\" -f ~/.ssh/id_rsa || true"
else
	info "Les clefs existent."
fi
LN

info "Copy de la clef public"
exec_cmd "ssh-copy-id -i ~/.ssh/id_rsa.pub ${user}@${server}"
LN
