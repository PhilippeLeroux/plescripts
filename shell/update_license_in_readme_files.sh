#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

function license_exists_at_line # $1 nr line before end $2 full path file
{
	[ "$(tail -n $1 $2 | head -1)" = "License" ] && return 0 || return 1
}

function update_file # $1 nr license lines $2 file name to upadte
{
	typeset -ri license_lines=$1
	typeset -ri license_at_line=license_lines-1
	typeset -r	full_file_name=$2

	license_exists_at_line $license_at_line "$full_file_name"
	if [ $? -eq 0 ]
	then
		info "Update license to $full_file_name"
		exec_cmd "sed -i -e :a -e '\$d;N;2,${license_lines}ba' -e 'P;D' $full_file_name"
	else
		info "Add license to $full_file_name"
	fi
	exec_cmd "cat $license_file >> $full_file_name"
	LN
}

typeset -r license_file=~/plescripts/license
exit_if_file_not_exists $license_file
typeset license_lines=$( wc -l <<<"$( cat $license_file )" )

info "$license_lines lines in $license_file"
LN

typeset -r cmd_find="find ~/plescripts/ -name readme.txt"
fake_exec_cmd $cmd_find
while read full_file_name
do
	update_file $license_lines "$full_file_name"
	LN
done<<<"$(eval $cmd_find)"

update_file $license_lines "~/plescripts/README.md"
LN
