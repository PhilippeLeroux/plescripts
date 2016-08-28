#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -host=<str> | -ip=<str>
	-host supprime du fichier ~/.ssh/know_hosts le nom d'hôte passé en paramètre et
	son adresse IP.

	-ip supprime du fichier ~/.ssh/know_hosts les lignes commençant par l'ip
"

info "Running : $ME $*"

typeset host=undef
typeset ip=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-host=*)
			host=${1##*=}
			shift
			;;

		-ip=*)
			ip=${1##*=}
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

if [ $host != undef ]
then
	remove_from_known_hosts $host
elif [ $ip != undef ]
then
	remove_ip_from_known_hosts $ip
else
	error "Missing parameter."
	info "$str_usage"
	exit 1
fi

#	Nettoyage des lignes vides, mais ne devrait plus arriver.
exec_cmd sed -i '/^$/d' ~/.ssh/known_hosts

exit 0
