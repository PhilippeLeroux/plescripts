#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

#Doit être exécuté sur le serveur d'infrastructure ou le master.

line_separator
info "Setup english for OS logs"
exec_cmd localectl set-locale LANG=en_US.UTF-8
LN

line_separator
. ~/plescripts/oracle_preinstall/make_vimrc_file	# Charge la fonction make_vimrc_file
make_vimrc_file "/root"

line_separator
cat ~/plescripts/setup_first_vms/for_inputrc /etc/inputrc > new_inputrc
mv new_inputrc /etc/inputrc
LN

line_separator
info "Remove samba."
exec_cmd yum -y erase samba-client.x86_64 samba-client-libs.x86_64 samba-common.noarch samba-common-libs.x86_64 samba-common-tools.x86_64 samba-libs.x86_64
LN
