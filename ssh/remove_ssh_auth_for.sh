#!/bin/bash

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -server_name=hostname.domain
		Supprime toutes les autorisations ssh pour les comptes root, grid et oracle
		du serveur server_name"

typeset server_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-server_name=*)
			server_name=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef server_name	"$str_usage"

IFS='.' read hn dn<<<"$server_name"
if [ x"$dn" = x ]
then
	warning "'$server_name' ne contient pas le nom de domaine."
fi

if [ ! -f ~/.ssh/authorized_keys ]
then
	info "~/.ssh/authorized_keys not exists."
	exit 1
fi

info "Supprime les autorisations de $server_name pour root"
count=$(grep -E "${server_name}$" ~/.ssh/authorized_keys | wc -l)
if [ $count -ne 0 ]
then
	exec_cmd "sed -i \"s/.*${server_name}$//g\" ~/.ssh/authorized_keys"
else
	info "Clef non trouvée."
fi
LN

info "Supprime les autorisations de $server_name pour oracle"
count=$(grep -E "${server_name}$" /home/oracle/.ssh/authorized_keys | wc -l)
if [ $count -ne 0 ]
then
	exec_cmd "sed -i \"s/.*${server_name}$//g\" /home/oracle/.ssh/authorized_keys"
else
	info "Clef non trouvée."
fi
LN

info "Supprime les autorisations de $server_name pour grid"
count=$(grep -E "${server_name}$" /home/grid/.ssh/authorized_keys | wc -l)
if [ $count -ne 0 ]
then
	exec_cmd "sed -i \"s/.*${server_name}$//g\" /home/grid/.ssh/authorized_keys"
else
	info "Clef non trouvée."
fi
LN
