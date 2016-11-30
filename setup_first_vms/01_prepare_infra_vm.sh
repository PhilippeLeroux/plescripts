#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

info "Update /etc/hostname with ${infra_hostname}.${infra_domain}"
exec_cmd "echo \"${infra_hostname}.${infra_domain}\" > /etc/hostname"
LN

line_separator
info "Create links on frequently used directories"
exec_cmd "ln -s ~/plescripts/san ~/san"
exec_cmd "ln -s ~/plescripts/dns ~/dns"
LN
