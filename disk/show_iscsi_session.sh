#!/bin/ksh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

exec_cmd "iscsiadm -m session -P 3"

#iscsiadm -m session -P 3 | grep "Attached scsi disk"
