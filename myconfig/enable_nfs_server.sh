#!/bin/sh
#	ts=4 sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME"

while [ $# -ne 0 ]
do
	case $1 in
		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

line_separator
exec_cmd sudo "systemctl enable rpcbind"
exec_cmd sudo "systemctl start rpcbind"
LN

line_separator
exec_cmd sudo "systemctl enable nfs-server"
exec_cmd sudo "systemctl start nfs-server"
LN

line_separator
info "Export $HOME/plescripts & $HOME/oracle_install :"
sudo -i <<EOS
echo "$HOME/plescripts ${infra_network}.0/24(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
mkdir -p $HOME/${oracle_install}
echo "$HOME/ISO/${oracle_install} ${infra_network}.0/24(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
exportfs -a
EOS
LN

line_separator
info "Open port for NFS server !"
line_separator

