#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/db/wallet/walletlib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME

Supprime toutes les connexions, doit être exécuté sur tous les noeuds d'un
cluster dataguard on d'un cluster RAC dont ORACLE_HOME n'est pas sur un CFS."

script_banner $ME $*

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

while read nu connect_string user
do
	[ x"$nu" == x ] && continue || true

	exec_cmd "~/plescripts/db/wallet/delete_credential.sh -tnsalias=$connect_string"
done<<<"$(mkstore -wrl $wallet_path -nologo -listCredential<<EOS|grep -E "^[0-9]*:"
$oracle_password
EOS
)"

exit 0
