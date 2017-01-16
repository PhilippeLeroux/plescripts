#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

typeset guest_addition_path="$HOME/.config/VirtualBox"
typeset vm_name=undef

typeset -r str_usage=\
"Usage :
$ME
	-vm_name=<name>
	[-guest_addition_path=$guest_addition_path]
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-vm_name=*)
			vm_name=${1##*=}
			shift
			;;

		-guest_addition_path=*)
			guest_addition_path=${1##*=}
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

exit_if_param_undef	vm_name "$str_usage"

typeset -r vbox_version=$(VBoxManage --version | cut -d_ -f1)
typeset -r guest_iso=$guest_addition_path/VBoxGuestAdditions_${vbox_version}.iso

if [ ! -d $guest_addition_path ]
then
	error "Dir not exists : $guest_addition_path"
	LN
	info "$str_usage"
	LN
	exit 1
fi

if [ ! -f $guest_iso ]
then
	error "Not found : $guest_iso"
	LN
	info "Guest addition path : $guest_addition_path"
	info "VBox version        : $vbox_version"
	LN
	info "$str_usage"
	LN
	exit 1
fi

info "Attach guest additions to $vm_name"
add_dynamic_cmd_param "storageattach $vm_name"
add_dynamic_cmd_param "--storagectl IDE --port 0 --device 0 --type dvddrive"
add_dynamic_cmd_param "--medium \"$guest_iso\""
exec_dynamic_cmd "VBoxManage"
LN
