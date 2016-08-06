#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r str_usage="Usage : $0"

typeset all=undef

while [ $# -ne 0 ]
do
	case $1 in
		*)
			error "Arg '$1' invalid."
			LN
			info $str_usage
			exit 1
			;;
	esac
done

function unregister_all
{
	typeset -r initiator_name=$(cat /etc/iscsi/initiatorname.iscsi | cut -d= -f2)
	info "logout : $initiator_name"
	exec_cmd -c "iscsiadm -m node -T $initiator_name -p $san_ip_priv --logout"
	exec_cmd -c "iscsiadm -m node --op delete --targetname $initiator_name"
	LN
}

info "Unregister all luns"
unregister_all
