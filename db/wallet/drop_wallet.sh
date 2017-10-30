#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/db/wallet/walletlib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME

Supprime un wallet store et sa configuration.

RAC : prend en charge un 'wallet store' non stocké sur un CFS.

Dataguard : exécuter le script sur tous les nœuds.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

must_be_user oracle

info "Remove wallet configuration."
# sed plante si le fichier n'existe pas, donc utilisation de -c
execute_on_all_nodes_v2 -c 'sed -i "/WALLET_LOCATION/d" $TNS_ADMIN/sqlnet.ora'
execute_on_all_nodes_v2 -c 'sed -i "/SQLNET.WALLET_OVERRIDE/d" $TNS_ADMIN/sqlnet.ora'
LN

if [ -d "$wallet_path" ]
then
	info "$(replace_paths_by_shell_vars $wallet_path) exists : "
	execute_on_all_nodes "rm -rf $wallet_path"
	LN
else
	info "no wallet store exists."
fi
