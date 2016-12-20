#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-wallet_path=path
"

script_banner $ME $*

typeset	wallet_path=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-wallet_path=*)
			wallet_path=${1##*=}
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

exit_if_param_undef wallet_path

#	Si ORACLE_HOME n'est pas un CFS il faut copier le store sur les autres nœuds.
function create_wallet_store
{
	mkdir -p $wallet_path

	fake_exec_cmd mkstore -wrl $wallet_path -create
	mkstore -wrl $wallet_path -create<<-EOS
	$oracle_password
	$oracle_password
	EOS
}

function update_sqlnet_ora
{
	if [ -f $TNS_ADMIN/sqlnet.ora ]
	then
		exec_cmd "sed -i '/WALLET_LOCATION/d' $TNS_ADMIN/sqlnet.ora"
		exec_cmd "sed -i '/SQLNET.WALLET_OVERRIDE/d' $TNS_ADMIN/sqlnet.ora"
	fi
	cat <<-EOC >> $TNS_ADMIN/sqlnet.ora
	WALLET_LOCATION = ( SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = $wallet_path) ) )

	SQLNET.WALLET_OVERRIDE = TRUE
	EOC
}

function create_pki
{
	fake_exec_cmd orapki wallet create -wallet $wallet_path -auto_login
	orapki wallet create -wallet $wallet_path -auto_login<<-EOP
	$oracle_password
	EOP
}

function copy_tns_file
{
	line_separator
	for node in $gi_node_list
	do
		info "copy store & tns to $node"
		exec_cmd scp -pr $TNS_ADMIN/sqlnet.ora ${node}:$TNS_ADMIN/sqlnet.ora
		LN
	done
}

[ ! -d $wallet_path ] && create_wallet_store && true

update_sqlnet_ora

create_pki

[ $gi_count_nodes -gt 1 ] && copy_tns_file || true
