#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name
"

info "Running : $ME $*"

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

# firewall-cmd --zone=zone --add-port=7777/tcp --add-port=7777/udp
# firewall-cmd --permanent --zone=zone --add-port=7777/tcp --add-port=7777/udp
info "Remove cluster OCFS $db"
LN

exec_cmd o2cb remove-cluster $db 
LN

exec_cmd rm -f /etc/ocfs2/cluster.conf
LN

exec_cmd systemctl stop o2cb
LN
exec_cmd systemctl stop ocfs2
LN

exec_cmd systemctl disable o2cb
LN
exec_cmd systemctl disable ocfs2
LN
