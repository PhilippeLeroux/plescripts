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

exit_if_dir_not_exists $guest_addition_path "$str_usage"

typeset -r vbox_version=$(VBoxManage --version | cut -d_ -f1)
typeset	-r iso_name=VBoxGuestAdditions_${vbox_version}.iso
typeset -r full_iso_name=$guest_addition_path/VBoxGuestAdditions_${vbox_version}.iso

if [ ! -f $full_iso_name ]
then
	warning "ISO not found : $full_iso_name"
	LN

	info "Download $iso_name"
	fake_exec_cmd cd $guest_addition_path
	cd $guest_addition_path
	exec_cmd wget http://download.virtualbox.org/virtualbox/$vbox_version/$iso_name
	fake_exec_cmd cd -
	cd -
	LN
	info "ISO lists :"
	exec_cmd ls -rlt $guest_addition_path/VBoxGuestAdditions*
	LN
fi

info "Attach guest additions to $vm_name"
add_dynamic_cmd_param "storageattach $vm_name"
add_dynamic_cmd_param "--storagectl IDE --port 0 --device 0 --type dvddrive"
add_dynamic_cmd_param "--medium $full_iso_name"
exec_dynamic_cmd "VBoxManage"
LN
