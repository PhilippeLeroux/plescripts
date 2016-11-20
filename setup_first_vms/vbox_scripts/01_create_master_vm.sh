#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME [-emul]"

script_banner $ME $*

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
			rm -f $PLELIB_LOG_FILE
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

script_start

line_separator
exec_cmd -ci "~/plescripts/validate_config.sh >/tmp/vc 2>&1"
if [ $? -ne 0 ]
then
	cat /tmp/vc
	rm -f /tmp/vc
	exit 1
fi
rm -f /tmp/vc

line_separator
info "Clean up know_host file of $client_hostname :"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh		\
									-host=${master_name}	\
									-ip=${master_ip}
LN

line_separator
exec_cmd "$vm_scripts_path/create_iface.sh -force_iface_name=vboxnet1"

line_separator
info "Create VM $master_name"
exec_cmd VBoxManage createvm	--name $master_name					\
								--basefolder \"$vm_path\" --register
LN

line_separator
info "Setup global config"
exec_cmd VBoxManage modifyvm $master_name --ostype Oracle_64
exec_cmd VBoxManage modifyvm $master_name --acpi on
exec_cmd VBoxManage modifyvm $master_name --ioapic on
exec_cmd VBoxManage modifyvm $master_name --memory $vm_memory_mb_for_master
exec_cmd VBoxManage modifyvm $master_name --vram 9
exec_cmd VBoxManage modifyvm $master_name --cpus 2
exec_cmd VBoxManage modifyvm $master_name --rtcuseutc on
exec_cmd VBoxManage modifyvm $master_name --largepages on
exec_cmd VBoxManage modifyvm $master_name --hpet on
LN

line_separator
info "Add Iface 1 : allow network connection only with $client_hostname"
exec_cmd VBoxManage modifyvm $master_name --nic1 hostonly
exec_cmd VBoxManage modifyvm $master_name --hostonlyadapter1 vboxnet1
exec_cmd VBoxManage modifyvm $master_name --nictype1 virtio
exec_cmd VBoxManage modifyvm $master_name --cableconnected1 on
LN

line_separator
info "Add Iface 2: Interco iSCSI"
exec_cmd VBoxManage modifyvm $master_name --nic2 intnet
exec_cmd VBoxManage modifyvm $master_name --nictype2 virtio
exec_cmd VBoxManage modifyvm $master_name --cableconnected2 on
LN

line_separator
typeset	-r full_ks_linux_iso_name=$iso_ks_olinux_path/${full_linux_iso_name##*/}
typeset	use_iso=$full_linux_iso_name
[ -f $full_ks_linux_iso_name ] && use_iso=$full_ks_linux_iso_name
info "Attach ISO : Oracle Linux"
exec_cmd VBoxManage storagectl $master_name --name IDE --add IDE --controller PIIX4

exec_cmd VBoxManage storageattach $master_name --storagectl IDE	\
						 --port 0 --device 0 --type dvddrive --medium \"$use_iso\"
LN

line_separator
info "Create storage controller."
exec_cmd VBoxManage storagectl $master_name	\
					--name SATA --add SATA --controller IntelAhci --portcount 1
LN

line_separator
info "Create and attach OS disk :"
exec_cmd "$vm_scripts_path/add_disk.sh					\
				-vm_name=$master_name					\
				-disk_name=\"$master_name\"				\
				-disk_mb=$(( 16 * 1024 ))" -fixed_size
LN

line_separator
info "Add $master_name to group Master"
exec_cmd VBoxManage modifyvm "$master_name" --groups "/Master"
LN

line_separator
info "Start VM $master_name, install will begin..."
exec_cmd VBoxManage startvm  $master_name
LN

line_separator
if [ "$use_iso" == "$full_linux_iso_name" ]
then
	info "Start graphical install."
else
	info "Start kickstart install"
fi
LN

script_stop $ME

info "After install execute : ./02_create_infra_vm.sh"
LN
