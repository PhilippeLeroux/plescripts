#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME

A utiliser quand Virtual Box perd sa config.
"

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

# $1 vm name
# return 0 if vm exists, else return 1
function vm_exists
{
	VBoxManage list vms|grep -qE $1
}

# $1 path
function register_vms
{
	info "Path $1"
	while read vbox_file
	do
		name=${vbox_file##*/}
		name=${name%.*}
		info "Register $name"
		if vm_exists $name
		then
			info "vm is already registered."
		else
			exec_cmd -c VBoxManage registervm "$vbox_file"
		fi
		LN
	done<<<"$(find "$1/" -name "*.vbox")"
	LN
}

register_vms "$HOME"

line_separator
exec_cmd "~/plescripts/virtualbox/create_iface.sh -force_iface_name=$hostifname"
LN
