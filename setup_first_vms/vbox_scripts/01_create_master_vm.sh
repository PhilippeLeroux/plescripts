#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC
typeset -r str_usage=\
"Usage : $ME [-emul]"

info "Running : $ME $*"

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

typeset -r script_start_at=$SECONDS

line_separator
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${master_name}
LN

line_separator
exec_cmd "$vm_scripts_path/create_iface.sh -force_iface_name=vboxnet1"

line_separator
info "Create VM $master_name"
exec_cmd VBoxManage createvm --name $master_name --basefolder \"$vm_path\" --register
LN

line_separator
info "Global config"
exec_cmd VBoxManage modifyvm $master_name --ostype Oracle_64
exec_cmd VBoxManage modifyvm $master_name --acpi on
exec_cmd VBoxManage modifyvm $master_name --ioapic on
exec_cmd VBoxManage modifyvm $master_name --memory $vm_memory_mb_for_master
exec_cmd VBoxManage modifyvm $master_name --vram 9
exec_cmd VBoxManage modifyvm $master_name --cpus 4
exec_cmd VBoxManage modifyvm $master_name --rtcuseutc on
exec_cmd VBoxManage modifyvm $master_name --largepages on
LN

line_separator
info "Add Iface 1"
exec_cmd VBoxManage modifyvm $master_name --nic1 hostonly
exec_cmd VBoxManage modifyvm $master_name --hostonlyadapter1 vboxnet1
exec_cmd VBoxManage modifyvm $master_name --nictype1 virtio
LN

line_separator
info "Add Iface 2"
exec_cmd VBoxManage modifyvm $master_name --nic2 intnet
exec_cmd VBoxManage modifyvm $master_name --nictype2 virtio
LN

line_separator
info "Attache l'ISO permettant d'installer Oracle Linux"
exec_cmd VBoxManage storagectl $master_name --name IDE --add IDE --controller PIIX4
exec_cmd VBoxManage storageattach $master_name --storagectl IDE --port 0 --device 0 --type dvddrive --medium \"$full_linux_iso_name\"
LN

line_separator
info "Crée et attache le disque où sera installé l'OS."
exec_cmd VBoxManage createhd --filename \"$vm_path/$master_name/$master_name.vdi\" --size 32768
exec_cmd VBoxManage storagectl $master_name --name SATA --add SATA --controller IntelAhci --portcount 1
exec_cmd VBoxManage storageattach $master_name --storagectl SATA --port 0 --device 0 --type hdd --medium \"$vm_path/$master_name/$master_name.vdi\"
LN

line_separator
info "Ajoute $master_name au groupe Master"
exec_cmd VBoxManage modifyvm "$master_name" --groups "/Master"
LN

line_separator
info "Démarrage de la VM $master_name, l'installation va commencer..."
exec_cmd VBoxManage startvm  $master_name
LN

info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
