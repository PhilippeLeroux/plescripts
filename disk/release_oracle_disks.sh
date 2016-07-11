#/bin/bash

#	ts=4 sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

oracleasm listdisks | while read disk_name
do
	info "Rend le disque $disk_name à l'OS"
	exec_cmd oracleasm deletedisk $disk_name
done
