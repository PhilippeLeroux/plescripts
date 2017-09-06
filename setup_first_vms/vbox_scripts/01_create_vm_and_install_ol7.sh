#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME [-emul]

Création d'une VM avec une configuration minimal et installation de l'OS.
Après l'installation la VM aura l'IP et le nom de la VM master.
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

ple_enable_log -params $PARAMS

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
exec_cmd ~/plescripts/shell/remove_from_known_host.sh			\
									-host=${master_hostname}	\
									-ip=${master_ip}
LN

line_separator
exec_cmd "$vm_scripts_path/create_iface.sh -force_iface_name=$hostifname"

line_separator
info "Create VM $master_hostname"
exec_cmd VBoxManage createvm	--name $master_hostname					\
								--groups "/Master"						\
								--basefolder \"$vm_path\" --register
LN

line_separator
info "Setup global config"
exec_cmd VBoxManage modifyvm $master_hostname --ostype Oracle_64
exec_cmd VBoxManage modifyvm $master_hostname --acpi on
exec_cmd VBoxManage modifyvm $master_hostname --ioapic on
exec_cmd VBoxManage modifyvm $master_hostname --memory $vm_memory_mb_for_master
exec_cmd VBoxManage modifyvm $master_hostname --vram 9
exec_cmd VBoxManage modifyvm $master_hostname --cpus 2
exec_cmd VBoxManage modifyvm $master_hostname --rtcuseutc on
exec_cmd VBoxManage modifyvm $master_hostname --largepages on
exec_cmd VBoxManage modifyvm $master_hostname --hpet on
exec_cmd VBoxManage modifyvm $master_hostname --x2apic on
exec_cmd VBoxManage modifyvm $master_hostname --audio none
LN

line_separator
info "Add Iface 1 : allow network connection only with $client_hostname"
exec_cmd VBoxManage modifyvm $master_hostname --nic1 hostonly
exec_cmd VBoxManage modifyvm $master_hostname --hostonlyadapter1 $hostifname
exec_cmd VBoxManage modifyvm $master_hostname --nictype1 virtio
exec_cmd VBoxManage modifyvm $master_hostname --cableconnected1 on
LN

line_separator
info "Add Iface 2: Interco iSCSI"
exec_cmd VBoxManage modifyvm $master_hostname --nic2 intnet
exec_cmd VBoxManage modifyvm $master_hostname --nictype2 virtio
exec_cmd VBoxManage modifyvm $master_hostname --cableconnected2 on
LN

line_separator
typeset	-r full_ks_linux_iso_name=$iso_ks_olinux_path/${full_linux_iso_name##*/}
typeset	use_iso=$full_linux_iso_name
[ -f $full_ks_linux_iso_name ] && use_iso=$full_ks_linux_iso_name
info "Attach ISO : Oracle Linux"
exec_cmd VBoxManage storagectl $master_hostname --name IDE --add IDE	\
												--controller PIIX4

exec_cmd VBoxManage storageattach $master_hostname --storagectl IDE		\
			--port 0 --device 0 --type dvddrive --medium \"$use_iso\"
LN

line_separator
info "Create storage controller."
exec_cmd VBoxManage storagectl $master_hostname	\
					--name SATA --add SATA --controller IntelAhci --portcount 1
LN

line_separator
#	Changement de comportement ente la version 5.1.6 et 5.1.8 de VBox
#		5.1.6 : lors du clonage on avait un disque de taille fixe.
#		5.1.8 : lors du clonage l'attribut 'taille fixe' est perdu
#	Régression ??
#	Je supprime le paramètre -fixed_size et passe la taille du disque de 16 à 24
info "Create and attach OS disk :"
exec_cmd "$vm_scripts_path/add_disk.sh						\
				-vm_name=$master_hostname					\
				-disk_name=\"$master_hostname\"				\
				-disk_mb=$(( 24 * 1024 ))"
LN

line_separator
info "Add $master_hostname to group Master"
exec_cmd VBoxManage modifyvm "$master_hostname" --groups "/Master"
LN

line_separator
info "Start VM $master_hostname, install will begin..."
exec_cmd VBoxManage startvm  $master_hostname
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

info "After install execute : ./02_install_vm_infra.sh"
LN
