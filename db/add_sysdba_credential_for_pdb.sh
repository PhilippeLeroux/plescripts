#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -db=name -pdb=name [-service=auto]

Le script prend en charge les RACs.

Pour un dataguard exécuter ce script sur tous les nœuds."

typeset db=undef
typeset pdb=undef
typeset	service=auto

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-service=*)
			service=${1##*=}
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

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

[ $service == auto ] && service=$(mk_oci_service $pdb) || true

typeset -r tnsalias=sys${pdb}

exec_cmd ~/plescripts/db/add_tns_alias.sh					\
								-tnsalias=$tnsalias			\
								-service=$service			\
								-host_name=$gi_current_node
LN

if [ $gi_count_nodes -gt 1 ]
then # Pour les RACs, l'alias TNS connecte sur le nœud locale.
	for node in ${gi_node_list[*]}
	do
		exec_cmd "ssh ${node} '. .bash_profile;						\
								~/plescripts/db/add_tns_alias.sh	\
										-tnsalias=$tnsalias			\
										-service=$service			\
										-host_name=$node'"
		LN
	done
fi

#	Pour les RACs create_credential.sh fait le nécessaire.
exec_cmd ~/plescripts/db/wallet/create_credential.sh	\
								-tnsalias=$tnsalias		\
								-user=sys				\
								-password=$oracle_password
LN

info "Connection to pdb $pdb with sys user :"
info "$ sqlplus /@${tnsalias} as sysdba"
LN
