#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -ri count_lv_error=$(lvs 2>/dev/null| grep -E "*asm01 .*\-a\-.*$" | wc -l)
if [ $count_lv_error -ne 0 ]
then
	info "LV errors : $count_lv_error"
	LN
	exec_cmd -c systemctl status target -l
	LN
	exec_cmd systemctl start target
	LN
	exec_cmd systemctl status target -l
else
	exit 0
fi
