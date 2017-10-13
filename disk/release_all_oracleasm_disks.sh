#/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

oracleasm listdisks | while read disk_name
do
	info "Release disk $disk_name"
	exec_cmd oracleasm deletedisk $disk_name
done
