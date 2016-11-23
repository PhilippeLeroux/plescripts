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
	echo "    $ ssh root@K2"
	echo "    $ cd ~/san"
	while read lv_name vg_name rem
	do
		read prefix name no <<<"$(echo $lv_name|sed "s/\(..\)\(.*\)\([0-9].\)$/\1 \2 \3/")"
		echo "    $ ./remove_lv.sh -vg_name=$vg_name -prefix=$name -first_no=$no"
	done<<<"$(lvs 2>/dev/null| grep -E "*asm01 .*\-a\-.*$")"
}

function cmd_restore_vg_link
{
	echo "    $ ssh root@K2"
	echo "    $ cd ~/scan"
	echo "    $ ./restore_vg_links.sh -vg_name=$vg_name"
}

function print_error_help
{
	echo "Solutions :"
	echo "1 : reboot server $(hostname -s)"
	echo "From host :"
	echo "    $ reboot $(hostname -s)"
	echo
	echo "2 : restore links"
	cmd_restore_vg_link
	echo
	echo "3 : remove lv"
	cmd_remove_lv
	echo
}

function restart_target
{
	info "Restart target :"

	exec_cmd -c systemctl status target -l
	LN
	
	exec_cmd -c systemctl stop target
	LN
	
	exec_cmd systemctl start target
	LN
	
	exec_cmd systemctl status target -l
	LN
}

typeset -i lv_errors=$(count_lv_errors)
if [ $lv_errors -ne 0 ]
then
	info "target [$KO]"
	error "LV errors : $lv_errors"
	LN

	restart_target

	lv_errors=$(count_lv_errors)
	if [ $lv_errors -ne 0 ]
	then
		error "$lv_errors LV(s) errors"
		error "LV orphaned, missing link or bug ??"
		LN

		show_lv_errors
		LN
		print_error_help
		LN
		info "target [$KO]"
		exit 1
	fi
else
	exec_cmd -c "systemctl status target" >/dev/null 2>&1
	[ $? -ne 0 ] && restart_target || true
	info "target [$OK]"
	exit 0
fi
