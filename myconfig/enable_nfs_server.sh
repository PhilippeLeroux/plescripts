#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage="Usage : $ME"

while [ $# -ne 0 ]
do
	case $1 in
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

ple_enable_log -params $PARAMS

line_separator
exec_cmd sudo "systemctl enable rpcbind"
exec_cmd sudo "systemctl start rpcbind"
LN

line_separator
exec_cmd sudo "systemctl enable nfs-server"
exec_cmd sudo "systemctl start nfs-server"
LN

line_separator
function get_network_end
{
	case "$1" in
		8)	echo ".0.0.0"
			;;
		16)	echo ".0.0"
			;;
		24)	echo ".0"
			;;
		*)	echo "prefix '$1' invalid."
	esac
}

info "NFS export :"
export_options="sync,no_root_squash,no_subtree_check"
export_network=${infra_network}$(get_network_end $if_pub_prefix)/$if_pub_prefix
export_file=/etc/exports
mkdir -p $HOME/${oracle_install}
sudo -i <<EOS
echo "$HOME/plescripts ${export_network}(rw,$export_options)" >> $export_file
echo "$HOME/${oracle_install} ${export_network}(ro,$export_options)" >> $export_file
exportfs -au
exportfs -a
EOS
LN

line_separator
info "Open port for NFS server !"
