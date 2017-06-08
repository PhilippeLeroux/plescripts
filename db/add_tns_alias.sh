#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-service=name    Nom du service qui sera aussi le nom de l'alias
	-host_name=name  Nom de l'hôte.
	[-tnsalias=name] Nom de l'alias TNS, par défaut c'est le nom du service.
	[-dataguard_list=server list] Nom des autres serveurs du dataguard.
	[-copy_server_list=] Copie avec scp le tnsnames sur la liste des servers.
"

script_banner $ME $*

typeset service=undef
typeset host_name=undef
typeset copy_server_list
typeset tnsalias=undef
typeset dataguard_list=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-service=*)
			service=${1##*=}
			shift
			;;

		-host_name=*)
			host_name=${1##*=}
			shift
			;;

		-tnsalias=*)
			tnsalias=${1##*=}
			shift
			;;

		-copy_server_list=*)
			copy_server_list="${1##*=}"
			shift
			;;

		-dataguard_list=*)
			dataguard_list="${1##*=}"
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

exit_if_param_undef service		"$str_usage"
exit_if_param_undef host_name	"$str_usage"

#	Affiche sur la sortie standard la configuration de l'alias TNS.
#	$1	nom de l'alias
#	$2	nom du service
#	$3	nom du serveur
function get_alias_for
{
	typeset	-r	tnsalias=$1
	typeset	-r	service=$2
	typeset	-r	host_name=$3
cat<<EOA

$tnsalias =
	(DESCRIPTION =
		(ADDRESS =
			(PROTOCOL = TCP)
			(HOST = $host_name)
			(PORT = 1521)
		)
		(CONNECT_DATA =
			(SERVER = DEDICATED)
			(SERVICE_NAME = $service)
		)
	)
EOA
}

typeset	-r	tnsnames_file=$TNS_ADMIN/tnsnames.ora

if [ ! -d "$TNS_ADMIN" ]
then
	error "Directory TNS_ADMIN='$TNS_ADMIN' not exist."
	exit 1
fi

[ $tnsalias == undef ] && tnsalias=$service || true

info "Delete TNS alias $tnsalias if exists."
exec_cmd "~/plescripts/db/delete_tns_alias.sh -tnsalias=$tnsalias"
LN

info "Append new alias : $tnsalias"
#get_alias_for $tnsalias $service $host_name >> $tnsnames_file
#LN
if [ "$dataguard_list" == undef ]
then
	exec_cmd "~/plescripts/shell/gen_tns_alias.sh			\
						-service=$service					\
						-alias_name=$tnsalias				\
						-server_list=$host_name >> $tnsnames_file"
else
	exec_cmd "~/plescripts/shell/gen_tns_alias.sh			\
				-service=$service							\
				-alias_name=$tnsalias						\
				-server_list=\"$host_name $dataguard_list\" >> $tnsnames_file"
fi

for server_name in $copy_server_list
do
	info "Copy \$TNS_ADMIN/tnsnames.ora to $server_name"
	scp $tnsnames_file ${server_name}:$tnsnames_file
	LN
done

info "\$TNS_ADMIN/tnsnames.ora updated."
