#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-service=name    Nom du service qui sera aussi le nom de l'alias
	-host_name=name  Nom de l'hôte.
	[-tnsalias=name] Nom de l'alias TNS, par défaut c'est le nom du service.
	[-dataguard_list=server list] Nom des autres serveurs du dataguard.
"

typeset service=undef
typeset host_name=undef
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

typeset	-r	tnsnames_file=$TNS_ADMIN/tnsnames.ora

if [ ! -d "$TNS_ADMIN" ]
then
	error "Directory TNS_ADMIN='$TNS_ADMIN' not exist."
	exit 1
fi

[ $tnsalias == undef ] && tnsalias=$service || true

typeset	-r	hostn=$(hostname -s)

info "$hostn : Delete TNS alias $tnsalias if exists."
exec_cmd "~/plescripts/db/delete_tns_alias.sh -tnsalias=$tnsalias"

info "$hostn : Append new alias : $tnsalias"
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

info "$hostn : \$TNS_ADMIN/tnsnames.ora updated."
LN
