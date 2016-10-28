#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
EXEC_CMD_ACTION=EXEC

#	La clef public de l'host est copiée sur le serveur $1 pour les comptes
#		- root
#		- grid
#		- oracle
function copy_public_key
{
	typeset -r server_name=$1

	typeset -r user_name=root

	info "Copie la clef public de $user_name:$(hostname -s) sur $user_name@$server_name"
	exec_cmd "ssh-copy-id -i ~/.ssh/id_rsa.pub $user_name@$server_name"
	LN

	exec_cmd "scp ~/.ssh/id_rsa.pub $user_name@$server_name:~/.ssh/client_rsa.pub"
	LN

	info "Ajoute la clef pour oracle"
	exec_cmd -c ssh $user_name@$server_name "mkdir /home/oracle/.ssh"
	exec_cmd ssh $user_name@$server_name "\"cat ~/.ssh/client_rsa.pub >> /home/oracle/.ssh/authorized_keys\""
	exec_cmd -c ssh $user_name@$server_name "chown -R oracle:oinstall /home/oracle/.ssh"
	LN

	info "Ajoute la clef pour grid"
	exec_cmd -c ssh $user_name@$server_name "mkdir /home/grid/.ssh"
	exec_cmd ssh $user_name@$server_name "\"cat ~/.ssh/client_rsa.pub >> /home/grid/.ssh/authorized_keys\""
	exec_cmd -c ssh $user_name@$server_name "chown -R grid:oinstall /home/grid/.ssh"
	LN
}

#	============================================================
#	MAIN
#	============================================================
typeset -r str_usage=\
"Usage : $0 -remote_server=<str>
	Met en place les connections ssh sans mots de passes avec les comptes
	root, grid et oracle du serveur -remote_server

	Seul le mot de passe root sera demandé, s'il n'y a pas d'équivalence.
"

typeset remote_server=undef

while [ $# -ne 0 ]
do
	case $1 in
		-remote_server=*)
			remote_server=${1##*=}
			info "remote_server='$remote_server'"
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			LN
			exit 1
			;;
	esac
done

exit_if_param_undef remote_server	"$str_usage"

add_2_know_hosts $remote_server
LN

copy_public_key $remote_server
LN
