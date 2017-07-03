#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/db/wallet/walletlib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME -tnsalias=name -user=name

return 0 if tnsalias and user exists, else return 1"

typeset	tnsalias=undef
typeset	user=undef

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

		-user=*)
			user=${1##*=}
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

mkstore -wrl $wallet_path -nologo -listCredential<<EOS|grep -E "^[0-9]*:.*${tnsalias}.*${user}$"
$oracle_password
EOS
