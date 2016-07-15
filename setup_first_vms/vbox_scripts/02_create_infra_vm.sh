#!/bin/bash
#	ts=4 sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r str_usage=\
"Usage : $ME [-emul]"

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

function run_ssh
{
	exec_cmd "ssh root@$infra_ip \"$@\""
}
line_separator
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${master_ip}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${master_name}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${infra_ip}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${infra_hostname}
LN

line_separator
info "Arrêt de la VM $master_name"
exec_cmd -c VBoxManage controlvm $master_name acpipowerbutton
[ $? -eq 0 ] && ( info -n "Attend l'arrêt complet : "; pause_in_secs 20; LN )

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

line_separator
exec_cmd VBoxManage sharedfolder add $master_name --name "plescripts" --hostpath "$HOME/plescripts --automount"
LN

line_separator
info "Démarre la VM $infra_hostname"
exec_cmd "$vm_scripts_path/start_vm $infra_hostname"
LN
wait_server $master_ip
LN

line_separator
info "Copie la configuration des Ifaces sur $infra_hostname"
typeset -r if_cfg_path=~/plescripts/setup_first_vms/ifcfg_infra_server
update_value IPADDR	$infra_ip							$if_cfg_path/ifcfg-$if_pub_name
update_value DNS1	$infra_ip							$if_cfg_path/ifcfg-$if_pub_name
LN
update_value IPADDR	${if_priv_network}.${infra_ip_node}	$if_cfg_path/ifcfg-$if_priv_name
LN
update_value DNS1	$infra_ip							$if_cfg_path/ifcfg-$if_net_name
LN
exec_cmd "scp ~/plescripts/setup_first_vms/ifcfg_infra_server/* root@${master_ip}:/etc/sysconfig/network-scripts/"
LN

line_separator
info "Redémarrage de la VM $infra_hostname"
exec_cmd "$vm_scripts_path/stop_vm $infra_hostname"
info -n "Temporisation : "; pause_in_secs 20; LN
exec_cmd "$vm_scripts_path/start_vm $infra_hostname"
LN
wait_server $infra_ip
if [ $? -ne 0 ]
then	# Parfois un simple reboot suffit.
	info "Redémarrage de la VM $infra_hostname"
	exec_cmd "$vm_scripts_path/stop_vm $infra_hostname"
	info -n "Temporisation : "; pause_in_secs 20; LN
	exec_cmd "$vm_scripts_path/start_vm $infra_hostname"
	LN
	wait_server $infra_ip
	[ $? -ne 0 ] && exit 1
fi
LN

line_separator
info "Connexion ssh :"
exec_cmd "~/plescripts/shell/connections_ssh_with.sh -user=root -server=$infra_ip"
LN

line_separator
exec_cmd "$vm_scripts_path/compile_guest_additions.sh -host=${infra_ip}"
LN

info "Redémarrage de la VM $infra_hostname"
exec_cmd "$vm_scripts_path/stop_vm $infra_hostname"
info -n "Temporisation : "; pause_in_secs 20; LN
exec_cmd "$vm_scripts_path/start_vm $infra_hostname"
LN
wait_server $infra_ip
[ $? -ne 0 ] && exit 1

line_separator
run_ssh "mkdir /mnt/plescripts"

case $type_shared_fs in
	vbox)
		run_ssh "mount -t vboxsf plescripts /mnt/plescripts"
		;;

	nfs)
		info "Création des points de montage NFS :"
		run_ssh "mkdir plescripts"
		run_ssh "mount 192.170.100.1:/home/$common_user_name/plescripts /root/plescripts"
		run_ssh "mkdir -p ~/$oracle_install"
		run_ssh "mkdir zips"
		run_ssh "mount 192.170.100.1:/$common_user_name/kangs/ISO/$oracle_install /root/zips"
		;;
esac

run_ssh "ln -s /mnt/plescripts ~/plescripts"
LN

run_ssh "~/plescripts/setup_first_vms/02_update_config.sh"
run_ssh "~/plescripts/setup_first_vms/03_setup_infra_or_master.sh -role=infra"
LN

line_separator
info "Configure DNS"
run_ssh "~/plescripts/dns/install/01_install_bind.sh"
run_ssh "~/plescripts/dns/install/03_configure.sh"

run_ssh "~/plescripts/dns/add_server_2_dns.sh -name=$client_hostname -ip_node=1"
run_ssh "~/plescripts/dns/add_server_2_dns.sh -name=orclmaster -ip_node=$master_ip_node"
run_ssh "~/plescripts/dns/show_dns.sh"

line_separator
run_ssh "~/plescripts/shell/set_plymouth_them"
LN

line_separator
info "Redémarrage de la VM $infra_hostname"
exec_cmd "$vm_scripts_path/stop_vm $infra_hostname"
info -n "Temporisation : "; pause_in_secs 20; LN

line_separator
info "Ajuste la RAM"
exec_cmd VBoxManage modifyvm $infra_hostname --memory $vm_memory_mb_for_infra
LN

exec_cmd "$vm_scripts_path/start_vm $infra_hostname"
wait_server $infra_hostname
exec_cmd "~/plescripts/shell/connections_ssh_with.sh -user=root -server=$infra_hostname"
LN
