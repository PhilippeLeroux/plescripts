#!/bin/bash

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

info "Install bind, bind libs and utils..."
exec_cmd yum -y install bind bind-libs bind-utils

info "Finished."

