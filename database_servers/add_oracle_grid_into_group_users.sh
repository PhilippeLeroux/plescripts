#/bin/bash

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

info "Ajout des utilisateurs grid et oracle dans le groupe 'users' pour accéder aux points de montages."
exec_cmd "usermod -a -G users grid"
exec_cmd "usermod -a -G users oracle"
LN
