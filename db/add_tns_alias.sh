#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-service_name=name   Nom du service qui sera aussi le nom de l'alias
	-host_name=name      Nom de l'hôte.
	[-copy_server_list=] Copie avec scp le tnsnames sur la liste des servers.
"

script_banner $ME $*

typeset service_name=undef
typeset host_name=undef
typeset copy_server_list

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-service_name=*)
			service_name=$(to_upper ${1##*=})
			shift
			;;

		-host_name=*)
			host_name=${1##*=}
			shift
			;;

		-copy_server_list=*)
			copy_server_list="${1##*=}"
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

exit_if_param_undef service_name	"$str_usage"
exit_if_param_undef host_name		"$str_usage"

#	Affiche sur la sortie standard la configuration de l'alias TNS.
#	$1	service_name qui sera aussi le nom de l'alias.
#	$2	nom du serveur
function get_alias_for
{
	typeset	-r	service_name=$1
	typeset	-r	host_name=$2
cat<<EOA

$service_name =
	(DESCRIPTION =
		(ADDRESS =
			(PROTOCOL = TCP)
			(HOST = $host_name)
			(PORT = 1521)
		)
		(CONNECT_DATA =
			(SERVER = DEDICATED)
			(SERVICE_NAME = $service_name)
		)
	)
EOA
}

typeset	-r	tnsnames_file=$TNS_ADMIN/tnsnames.ora

if [ ! -d $TNS_ADMIN ]
then
	error "Directory TNS_ADMIN='$TNS_ADMIN' not exist."
	exit 1
fi

exec_cmd "~/plescripts/db/delete_tns_alias.sh -alias_name=$service_name"
LN

info "Append new alias : $service_name"
get_alias_for $service_name $host_name >> $tnsnames_file
LN

if [ x"$copy_server_list" != X ]
then
	for server_name in $copy_server_list
	do
		info "Copy \$TNS_ADMIN/tnsnames.ora to $server_name"
		scp $tnsnames_file ${server_name}:$tnsnames_file
		LN
	done
fi

info "\$TNS_ADMIN/tnsnames.ora updated."
