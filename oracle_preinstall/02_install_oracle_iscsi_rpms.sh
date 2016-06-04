#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

line_separator
info "Database Server 12cR1"
exec_cmd yum -y install oracle-rdbms-server-12cR1-preinstall
LN

line_separator
info "iscsi packags"
exec_cmd yum -y install iscsi-initiator-utils
LN

line_separator
info "git"
exec_cmd yum -y install git
LN
# Pour el6 ajouter lsscsi
