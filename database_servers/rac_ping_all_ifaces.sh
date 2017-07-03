#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME ...."

typeset		db=undef
typeset	-i	node=-1

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

		-node=*)
			node=${1##*=}
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

[[ $db == undef && x"$ID_DB" == x ]] && db=$ID_DB
exit_if_param_undef db		"$str_usage"
exit_if_param_undef node	"$str_usage"

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

if [ $max_nodes -lt 2 ]
then
	error "Valable uniquement pour un RAC."
	exit 1
fi

typeset	-ri	count_ping_error=0

for (( inode=1; inode <= max_nodes; ++inode ))
do
	[ $inode -eq $node ] && continue

	cfg_load_node_info $db $inode

	info "ping server $cfg_server_name :"
	exec_cmd -c ping -c 4 $cfg_server_name
	[ $? -ne 0 ] && count_ping_error=count_ping_error+1
	LN

	info "ping iSCSI Iface : $cfg_iscsi_ip"
	exec_cmd -c ping -c 4 $cfg_iscsi_ip
	[ $? -ne 0 ] && count_ping_error=count_ping_error+1
	LN
done

if [ $count_ping_error -ne 0 ]
then
	error "ping failed !"
	LN
	exit 1
else
	exit 0
fi
