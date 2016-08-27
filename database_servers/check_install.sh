#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=identifiant"

info "Running : $ME $*"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
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

[[ $db = undef ]] && [[ -v ID_DB ]] && db=$ID_DB
exit_if_param_undef db	"$str_usage"

#	Répertoire contenant le fichier de configuration de la db
typeset -r cfg_path=~/plescripts/database_servers/$db
[ ! -d $cfg_path ]	&& error "$cfg_path not exists." && exit 1

typeset -r node_name1=$(cut -d: -f2<$cfg_path/node1)
info "Check log on node $node_name1"
exec_cmd "ssh oracle@${node_name1} 'grep -n \"Error Message\" /u01/app/oraInventory/logs/installActions*'"
