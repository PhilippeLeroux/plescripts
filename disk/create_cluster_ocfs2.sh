#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-db=name
"

typeset	add_to_cluster=no

typeset	db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
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

exit_if_param_undef	db					"$str_usage"

cfg_exists $db

# firewall-cmd --zone=zone --add-port=7777/tcp --add-port=7777/udp
# firewall-cmd --permanent --zone=zone --add-port=7777/tcp --add-port=7777/udp
info "Create cluster OCFS $db"
exec_cmd o2cb add-cluster $db 
LN

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

line_separator
info "Make configuration :"
for (( inode=1; inode <= max_nodes; ++inode ))
do
	cfg_load_node_info $db $inode
	exec_cmd o2cb add-node $db $cfg_server_name --ip $cfg_iscsi_ip
	LN
done

line_separator
info "Configure o2cb"
fake_exec_cmd /sbin/o2cb.init configure CR CR $db CR CR CR CR
if [ $? -eq 0 ]
then
/sbin/o2cb.init configure<<EOC


$db




EOC
LN
fi

exec_cmd o2cb heartbeat-mode $db global
LN

exec_cmd systemctl enable o2cb
LN
exec_cmd systemctl enable ocfs2
LN
exec_cmd systemctl start o2cb
LN
exec_cmd systemctl start ocfs2
LN
exec_cmd /sbin/o2cb.init enable
LN
exec_cmd /sbin/o2cb.init status
LN
