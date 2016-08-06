#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

exec_cmd "iscsiadm -m session -P 3"
