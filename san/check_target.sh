#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

function count_lv_errors
{
	lvs 2>/dev/null| grep -E "*asm01 .*\-a\-.*$" | wc -l
}

function show_lv_errors
{
	lvs 2>/dev/null| grep -E "*asm01 .*\-a\-.*$"
}

#./remove_lv.sh -vg_name=asm01 -prefix=testsan -first_no=18
function cmd_remove_lv
{
	echo "cd ~/san"
	while read lv_name vg_name rem
	do
		read prefix name no <<<"$(echo $lv_name|sed "s/\(..\)\(.*\)\([0-9].\)$/\1 \2 \3/")"
		echo "./remove_lv.sh -vg_name=$vg_name -prefix=$name -first_no=$no"
	done<<<"$(lvs 2>/dev/null| grep -E "*asm01 .*\-a\-.*$")"
}

function restart_target
{
	info "Restart target :"

	exec_cmd -c systemctl status target -l
	LN
	
	exec_cmd systemctl start target
	LN
	
	exec_cmd systemctl start target
	LN
	
	exec_cmd systemctl status target -l
	LN
}

typeset -i lv_errors=$(count_lv_errors)
if [ $lv_errors -ne 0 ]
then
	error "LV errors : $lv_errors"
	LN

	restart_target

	lv_errors=$(count_lv_errors)
	if [ $lv_errors -ne 0 ]
	then
		error "$lv_errors LV(s) errors"
		error "LV orphaned or bug ??"
		LN

		show_lv_errors
		LN
		cmd_remove_lv
		LN
		exit 1
	fi
else
	exit 0
fi
