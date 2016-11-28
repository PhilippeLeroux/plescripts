#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
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
exec_cmd ~/plescripts/shell/remove_from_known_host.sh		\
									-host=${infra_hostname}	\
									-ip=${infra_ip}
LN

line_separator
info "Flush DNS cache, usefull during tests..."
exec_cmd -ci "sudo systemctl restart nscd.service"
LN

line_separator
exec_cmd -ci "~/plescripts/validate_config.sh >/tmp/vc 2>&1"
if [ $? -ne 0 ]
then
	cat /tmp/vc
	rm -f /tmp/vc
	exit 1
fi
rm -f /tmp/vc

#===============================================================================
function master_ip_is_pingable
{
	ping -c 1 $master_ip > /dev/null 2>&1
}

master_ip_is_pingable
if [ $? -eq 0 ]
then
	line_separator
	confirm_or_exit -reply_list=CR "root password for VM $master_name will be asked. Press enter to continue."
	exec_cmd "make_ssh_user_equivalence_with.sh -user=root -server=$master_ip"

	info "Stop VM $master_name"
	#	Normallement la VM est démarrée, si ce n'est pas le cas erreur mais continue.
	exec_cmd -c $vm_scripts_path/stop_vm -server=$master_name
	[ $? -eq 0 ] && timing 20 "Attend l'arrêt complet"
	LN
else
	start_vm $master_name
	timing 30 "Waiting server $master_name"
	add_2_know_hosts $master_ip
	exec_cmd -c $vm_scripts_path/stop_vm -server=$master_name
	[ $? -eq 0 ] && timing 20 "Attend l'arrêt complet"
	LN
fi

line_separator
info "Clone VM master"
exec_cmd VBoxManage clonevm $master_name --name $infra_hostname			\
							--basefolder \"$vm_path\" --register
LN

line_separator
info "Add NIC for internet connection"
exec_cmd VBoxManage modifyvm $infra_hostname --nic3 bridged
exec_cmd VBoxManage modifyvm $infra_hostname --bridgeadapter3 "enp3s0"
exec_cmd VBoxManage modifyvm $infra_hostname --nictype3 virtio
exec_cmd VBoxManage modifyvm $infra_hostname --cableconnected3 on
LN

line_separator
info "Settup 2 cpus"
exec_cmd VBoxManage modifyvm $infra_hostname --cpus 2

line_separator
info "Add disk for SAN storage (targetcli)"
exec_cmd $vm_scripts_path/add_disk.sh					\
				-vm_name=$infra_hostname				\
				-disk_name=asm01_disk01					\
				-disk_mb=$(( $san_disk_size_g * 1024 ))	\
				-fixed_size
LN

line_separator
info "Move $infra_hostname to group Infra"
exec_cmd VBoxManage modifyvm "$infra_hostname" --groups "/Infra"
LN

#	Le script start_vm ignore les actions spécifique du serveur d'infra.
export INSTALLING_INFRA=yes

line_separator
info "Start VM $infra_hostname"
exec_cmd "$vm_scripts_path/start_vm $infra_hostname -wait_os=no"
LN

#	La VM à encore l'IP du master.
exec_cmd wait_server $master_ip
LN

line_separator
typeset -r if_cfg_path=~/plescripts/setup_first_vms/ifcfg_infra_server
line_separator
info "Update public Iface : $if_pub_name"
update_value NAME	$if_pub_name	$if_cfg_path/ifcfg-$if_pub_name
update_value DEVICE	$if_pub_name	$if_cfg_path/ifcfg-$if_pub_name
update_value IPADDR	$infra_ip		$if_cfg_path/ifcfg-$if_pub_name
update_value PREFIX	$if_pub_prefix	$if_cfg_path/ifcfg-$if_pub_name
update_value DNS1	$infra_ip		$if_cfg_path/ifcfg-$if_pub_name
LN

info "Update iSCSI Iface : $if_iscsi_name"
update_value NAME	$if_iscsi_name							$if_cfg_path/ifcfg-$if_iscsi_name
update_value DEVICE	$if_iscsi_name							$if_cfg_path/ifcfg-$if_iscsi_name
update_value IPADDR	${if_iscsi_network}.${infra_ip_node}	$if_cfg_path/ifcfg-$if_iscsi_name
update_value PREFIX	$if_iscsi_prefix						$if_cfg_path/ifcfg-$if_iscsi_name
LN

info "Update internet Iface : $if_net_name"
update_value NAME	$if_net_name	$if_cfg_path/ifcfg-$if_net_name
update_value DEVICE	$if_net_name	$if_cfg_path/ifcfg-$if_net_name
update_value DNS1	$infra_ip		$if_cfg_path/ifcfg-$if_net_name
LN

info "Copy Ifaces files to $infra_hostname (Use IP $master_ip)"
exec_cmd "scp ~/plescripts/setup_first_vms/ifcfg_infra_server/* root@${master_ip}:/etc/sysconfig/network-scripts/"
LN

info "Restart VM $infra_hostname, new network config take effect."
exec_cmd "$vm_scripts_path/reboot_vm $infra_hostname"
LN
exec_cmd wait_server $infra_ip
[ $? -ne 0 ] && exit 1

line_separator
info "Add IP $infra_ip ($infra_hostname) into local know_host."
add_2_know_hosts $infra_ip
LN

line_separator
exec_cmd "~/plescripts/setup_first_vms/01_prepare_infra_vm.sh"

line_separator
info "Create yum repository"
exec_cmd "~/plescripts/yum/init_infra_repository.sh"
LN

line_separator
exec_cmd "ssh -t root@$infra_ip \"~/plescripts/setup_first_vms/02_update_config.sh\""
exec_cmd "ssh -t root@$infra_ip \"~/plescripts/setup_first_vms/03_setup_infra_vm.sh\""
LN

line_separator
info "Stop VM $infra_hostname to adjust RAM"
exec_cmd "$vm_scripts_path/stop_vm -server=$infra_hostname -wait_os"
LN

line_separator
info "Adjust RAM"
exec_cmd VBoxManage modifyvm $infra_hostname --memory $vm_memory_mb_for_infra
LN

line_separator
info "Start VM."
exec_cmd "$vm_scripts_path/start_vm $infra_hostname"
exec_cmd wait_server $infra_hostname

line_separator
info "Remove IP $master_ip & $infra_ip from known_host file of $client_name"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -ip=${master_ip}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -ip=${infra_ip}
LN

line_separator
info "Setup ssh equivalence between $client_hostname and $infra_hostname"
exec_cmd "~/plescripts/shell/make_ssh_user_equivalence_with.sh -user=root -server=$infra_hostname"
LN

script_stop $ME

info "Execute : ./03_install_vm_master.sh"
LN
