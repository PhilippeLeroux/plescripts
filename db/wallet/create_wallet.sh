#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/db/wallet/walletlib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

Chemin du wallet : $wallet_path

RAC : prend en charge un 'wallet store' non stocké sur un CFS.

Dataguard : exécuter le script sur tous les nœuds.

Note : le script create_credential.sh appel ce script si le 'wallet store'
n'existe pas.
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

function create_wallet_store
{
	info "Create wallet store."
	LN

	exec_cmd mkdir -p $wallet_path

	fake_exec_cmd "mkstore -wrl $wallet_path -create <<< $oracle_password"
	mkstore -wrl $wallet_path -nologo -create<<-EOS
	$oracle_password
	$oracle_password
	EOS
	LN
}

function update_sqlnet_ora
{
	info "Update sqlnet.ora"

	if [ -f $TNS_ADMIN/sqlnet.ora ]
	then # Efface la configuration si elle existe.
		exec_cmd "sed -i '/WALLET_LOCATION/d' $TNS_ADMIN/sqlnet.ora"
		exec_cmd "sed -i '/SQLNET.WALLET_OVERRIDE/d' $TNS_ADMIN/sqlnet.ora"
	fi
	cat <<-EOC >> $TNS_ADMIN/sqlnet.ora
	WALLET_LOCATION = ( SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = $wallet_path) ) )
	SQLNET.WALLET_OVERRIDE = TRUE
	EOC
	LN
}

function create_pki
{
	info "Create Oracle pki"
	LN
	fake_exec_cmd "orapki wallet create -wallet $wallet_path -auto_login <<< $oracle_password"
	orapki wallet create -wallet $wallet_path -auto_login<<-EOP
	$oracle_password
	EOP
	LN
}

function RAC_copy_wallet_store
{
	info "Update wallet on node(s) : ${gi_node_list[*]}"
	for node in ${gi_node_list[*]}
	do
		info "copy wallet store to $node"
		exec_cmd ssh ${node} mkdir -p $wallet_path
		exec_cmd scp -pr $wallet_path/* ${node}:$wallet_path/
		LN

		info "copy sqlnet.ora to $node"
		exec_cmd scp -pr $TNS_ADMIN/sqlnet.ora ${node}:$TNS_ADMIN/sqlnet.ora
		LN
	done
}

if [ -d $wallet_path ]
then
	error "Wallet store already exists."
	LN
	exit 1
fi

create_wallet_store

update_sqlnet_ora

create_pki

if [ $gi_count_nodes -gt 1 ] && ! wallet_store_on_cfs
then
	RAC_copy_wallet_store
fi
