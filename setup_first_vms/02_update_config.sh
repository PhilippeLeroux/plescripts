#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

info "Running : $ME $*"

#Doit être exécuté sur le serveur d'infrastructure ou le master.

line_separator
. ~/plescripts/oracle_preinstall/make_vimrc_file
make_vimrc_file "/root/.vimrc"

line_separator
cat ~/plescripts/setup_first_vms/for_inputrc /etc/inputrc > new_inputrc
mv new_inputrc /etc/inputrc
[ "$mode_vi" = "no" ] && sed -i "s/set editing-mode vi/#set editing-mode vi/" /etc/inputrc
LN

line_separator
info "Remove samba."
exec_cmd yum -y erase samba-client.x86_64 samba-client-libs.x86_64 samba-common.noarch samba-common-libs.x86_64 samba-common-tools.x86_64 samba-libs.x86_64

line_separator
test_if_rpm_update_available
[ $? -eq 0 ] && exec_cmd yum -y update || true
LN
