#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

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

line_separator
info "Nettoyage du fichier know_host de $client_hostname :"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${master_name}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${infra_hostname}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -ip=${master_ip}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -ip=${infra_ip}
LN

#===============================================================================
#	Validation des exports NFS depuis le poste client.
line_separator
info "Validation exports NFS :"
exec_cmd -c "sudo showmount -e localhost"
LN

typeset -i	nfs_errors=0
if [ $type_shared_fs == nfs ]
then
	exec_cmd -c "sudo showmount -e localhost | grep -q /home/$common_user_name/$oracle_install"
	[ $? -ne 0 ] && nfs_errors=nfs_errors+1 || info "${GREEN}Passed.${NORM}"

	exec_cmd -c "sudo showmount -e localhost | grep -q /home/$common_user_name/plescripts"
	[ $? -ne 0 ] && nfs_errors=nfs_errors+1 || info "${GREEN}Passed.${NORM}"
fi

exec_cmd -c "sudo showmount -e localhost | grep -q $iso_olinux_path"
[ $? -ne 0 ] && nfs_errors=nfs_errors+1  || info "${GREEN}Passed.${NORM}"
LN

if [ $nfs_errors -ne 0 ]
then
	info "Les exports NFS attendus depuis $client_hostname ne sont pas présent."
	exit 1
fi
#===============================================================================

line_separator
info "Arrêt de la VM $master_name"
exec_cmd -c VBoxManage controlvm $master_name acpipowerbutton
[ $? -eq 0 ] && timing 20 "Attend l'arrêt complet"

line_separator
info "Clonage de la VM master."
exec_cmd VBoxManage clonevm $master_name --name $infra_hostname --basefolder \"$vm_path\" --register
LN

line_separator
info "Ajout d'une carte pour la connexion internet."
exec_cmd VBoxManage modifyvm $infra_hostname --nic3 bridged
exec_cmd VBoxManage modifyvm $infra_hostname --bridgeadapter3 "enp3s0"
exec_cmd VBoxManage modifyvm $infra_hostname --nictype3 virtio
LN

line_separator
info "Attribution de 2 cpus"
exec_cmd VBoxManage modifyvm $infra_hostname --cpus 2

line_separator
info "Ajout d'un disque pour le SAN (targetcli)"
exec_cmd VBoxManage createhd --filename \"$vm_path/$infra_hostname/asm01.vdi\" --size 524288
exec_cmd VBoxManage storageattach $infra_hostname --storagectl SATA --port 1 --device 0 --type hdd --medium \"$vm_path/$infra_hostname/asm01.vdi\"
LN

line_separator
info "Ajoute $infra_hostname au groupe Infra"
exec_cmd VBoxManage modifyvm "$infra_hostname" --groups "/Infra"
LN

if [ $type_shared_fs == vbox ]
then
	line_separator
	exec_cmd VBoxManage sharedfolder add $master_name --name "plescripts" --hostpath "$HOME/plescripts --automount"
	LN
fi

line_separator
info "Démarre la VM $infra_hostname"
exec_cmd "$vm_scripts_path/start_vm $infra_hostname"
LN
wait_server $master_ip
LN

#	La VM infra vient d'être clonée depuis le master, elle possède donc la
#	configuration mimnimum du master : son nom et son adresse IP
info "Equivalence ssh temporaire par rapport à l'IP du master."
exec_cmd "~/plescripts/shell/make_ssh_user_equivalence_with.sh -user=root -server=$master_ip"
LN

line_separator
typeset -r if_cfg_path=~/plescripts/setup_first_vms/ifcfg_infra_server
line_separator
info "Mise à jour de la configuration de l'Iface public : $if_pub_name"
update_value IPADDR	$infra_ip		$if_cfg_path/ifcfg-$if_pub_name
update_value PREFIX	$if_pub_prefix	$if_cfg_path/ifcfg-$if_pub_name
update_value DNS1	$infra_ip		$if_cfg_path/ifcfg-$if_pub_name
LN

info "Mise à jour de la configuration de l'Iface iscsi : $if_iscsi_name"
update_value IPADDR	${if_iscsi_network}.${infra_ip_node}	$if_cfg_path/ifcfg-$if_iscsi_name
update_value PREFIX	$if_iscsi_prefix						$if_cfg_path/ifcfg-$if_iscsi_name
LN

info "Mise à jour de la configuration de l'Iface internet : $if_net_name"
update_value DNS1	$infra_ip	$if_cfg_path/ifcfg-$if_net_name
LN

info "Copie la configuration des Ifaces sur $infra_hostname (utilise l'IP $master_ip)"
exec_cmd "scp ~/plescripts/setup_first_vms/ifcfg_infra_server/* root@${master_ip}:/etc/sysconfig/network-scripts/"
LN

case $type_shared_fs in
	vbox)
		line_separator
		info "Compilation des 'Guest Additions'"
		exec_cmd "ssh -t root@$master_ip \"$vm_scripts_path/compile_guest_additions.sh -host=${master_ip}\""
		LN
		;;
esac

info "Redémarrage de la VM $infra_hostname, la nouvelle configuration réseau sera effective."
exec_cmd "$vm_scripts_path/reboot_vm $infra_hostname"
LN
wait_server $infra_ip
[ $? -ne 0 ] && exit 1

line_separator
exec_cmd "~/plescripts/setup_first_vms/01_prepare_infra_vm.sh"
exec_cmd "ssh -t root@$infra_ip \"~/plescripts/setup_first_vms/02_update_config.sh\""
exec_cmd "ssh -t root@$infra_ip \"~/plescripts/setup_first_vms/03_setup_infra_vm.sh\""
LN

line_separator
info "Arrêt de la VM $infra_hostname pour ajuster la RAM"
exec_cmd "$vm_scripts_path/stop_vm -server=$infra_hostname -wait_os"
LN

line_separator
info "Ajuste la RAM"
exec_cmd VBoxManage modifyvm $infra_hostname --memory $vm_memory_mb_for_infra
LN

line_separator
info "Démarre la VM."
exec_cmd "$vm_scripts_path/start_vm $infra_hostname"
wait_server $infra_hostname

line_separator
info "L'IP $master_ip n'est plus utile dans le known_host de $client_name"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -ip=${master_ip}
LN

line_separator
info "Équivalence ssh entre $client_hostname et $infra_hostname"
exec_cmd "~/plescripts/shell/make_ssh_user_equivalence_with.sh -user=root -server=$infra_hostname"
LN
