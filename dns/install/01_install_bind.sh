#!/bin/bash
# vim: ts=4:sw=4:ft=sh
# ft=sh car la colorisation ne fonctionne pas si le nom du script commence par
# un n°

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

info "Install bind, bind libs and utils..."
exec_cmd yum -y install bind bind-libs bind-utils

info "Finished."
