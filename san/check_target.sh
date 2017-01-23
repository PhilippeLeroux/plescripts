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

function cmd_restore_vg_link
{
	echo "    $ ssh root@K2"
	echo "    $ cd ~/scan"
	echo "    $ ./restore_vg_links.sh -vg_name='vg name'"
}

function print_error_help
{
	echo "Solutions :"
	echo "1 : reboot server $(hostname -s)"
	echo "From host :"
	echo "    $ reboot_vm $(hostname -s)"
	echo
	echo "2 : restore links"
	cmd_restore_vg_link
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

#	return 0 if backstore $1 exists, else return 1
function backstore_exists
{
	targetcli ls backstores/block/$1 >/dev/null 2>&1
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
		LN

		typeset -i lv_corrected=0
		while read lv_name vg_name rem
		do
			typeset backstore_name=${vg_name}_${lv_name}
			if ! backstore_exists $backstore_name
			then
				info "Backstore $backstore_name not exists."
				info "remove lv $lv_name from vg $vg_name"
				read prefix no <<<$(sed "s/lv\(.*\)\([0-9]\{2\}\)/\1 \2/g"<<<"$lv_name")
				exec_cmd -c ~/plescripts/san/remove_lv.sh		\
											-vg_name=$vg_name	\
											-prefix=$prefix		\
											-first_no=$no
				[ $? -eq 0 ] && ((lv_corrected++)) || true
				LN
			fi
		done<<<"$(lvs 2>/dev/null| grep -E "*asm01 .*\-a\-.*$")"

		if [ $lv_corrected -eq $lv_errors ]
		then
			info "target [$OK]"
			exit 0
		else
			show_lv_errors
			LN
			print_error_help
			LN
			info "target [$KO]"
			exit 1
		fi
	fi
else
	exec_cmd -c "systemctl status target" >/dev/null 2>&1
	[ $? -ne 0 ] && restart_target || true
	info "target [$OK]"
	exit 0
fi
