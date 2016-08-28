#/bin/bash

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

exec_cmd "usermod -a -G users grid"
exec_cmd "usermod -a -G users oracle"
LN
