#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

. ~/plescripts/oracle_preinstall/make_vimrc_file
make_vimrc_file "/root/.vimrc"

cat ~/plescripts/setup_first_vms/for_inputrc /etc/inputrc > new_inputrc
mv new_inputrc /etc/inputrc
[ "$mode_vi" = "no" ] && sed -i "s/set editing-mode vi/#set editing-mode vi/" /etc/inputrc
LN
