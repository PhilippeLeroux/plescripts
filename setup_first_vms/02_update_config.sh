#!/bin/bash

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

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
test_if_rpm_update_available
[ $? -eq 0 ] && exec_cmd yum -y update || true
LN

