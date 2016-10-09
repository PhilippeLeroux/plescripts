#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

line_separator
info "Install Oracle rdbms rpm"
exec_cmd yum -y install $oracle_rdbms_rpm
LN

line_separator
info "Install iscsi packages"
exec_cmd yum -y install iscsi-initiator-utils
LN

line_separator
info "Install git"
exec_cmd yum -y install git
LN

line_separator
info "Install rlwrap"
exec_cmd yum -y install ~/plescripts/rpm/rlwrap-0.42-1.el7.x86_64.rpm
LN
