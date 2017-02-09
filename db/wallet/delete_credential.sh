#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/db/wallet/walletlib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -tnsalias=name

RAC : prend en charge un 'wallet store' non stocké sur un CFS.

Dataguard : exécuter le script sur tous les nœuds.
"

script_banner $ME $*

typeset tnsalias=undef

#	Dans le cas d'un RAC ou d'un Dataguard le script sera exécuté sur tous les
#	nœuds sauf si le flag -local_only est utilisé.
typeset local_only=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-tnsalias=*)
			tnsalias=${1##*=}
			shift
			;;

		-local_only)
			local_only=yes
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

exit_if_param_undef tnsalias	"$str_usage"

fake_exec_cmd mkstore -wrl $wallet_path -nologo -deleteCredential $tnsalias
if [ $? -eq 0 ]
then
	mkstore -wrl $wallet_path -nologo -deleteCredential $tnsalias $password<<-EOP
	$oracle_password
	EOP

	if [[ $gi_count_nodes -gt 1 && $local_only == no ]] && ! wallet_store_on_cfs
	then
		execute_on_other_nodes -c	\
			". .bash_profile;								\
				~/plescripts/db/wallet/delete_credential.sh	\
										-tnsalias=$tnsalias	\
										-local_only"
	fi
fi

exit 0
