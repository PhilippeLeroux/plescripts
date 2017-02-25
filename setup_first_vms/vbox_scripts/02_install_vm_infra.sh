#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

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

ple_enable_log

script_banner $ME $*

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

function exec_ssh
{
	typeset	-r	conn="$1"
	shift

	exec_cmd "ssh -t $conn \"$@\""
}

function ssh_master
{
	exec_ssh root@${master_ip} "$@"
}

function ssh_infra
{
	exec_ssh root@${infra_ip} "$@"
}

master_ip_is_pingable
if [ $? -eq 0 ]
then
	#	La VM master vient d'être créée, elle est démarrée.
	line_separator
	confirm_or_exit -reply_list=CR "root password for VM $master_hostname will be asked. Press enter to continue."
	exec_cmd "make_ssh_user_equivalence_with.sh -user=root -server=$master_ip"

	info "Stop VM $master_hostname"
	#	Normalement la VM est démarrée, si ce n'est pas le cas erreur mais continue.
	exec_cmd stop_vm -server=$master_hostname -dataguard=no
	LN
else
	#	Je considère que l'équivalence est faite et que je recommence un test de
	#	création de la VM d'infra.
	exec_cmd start_vm $master_hostname -wait_os=no -dataguard=no
	exec_cmd wait_server $master_ip
	add_to_known_hosts $master_ip
	exec_cmd stop_vm -server=$master_hostname -dataguard=no
	LN
fi

line_separator
info "Clone VM master"
exec_cmd VBoxManage clonevm $master_hostname --name $infra_hostname			\
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
exec_cmd VBoxManage modifyvm $infra_hostname --cpus 2
LN

if [ 0 -eq 1 ]; then
# --hostiocache on : la CPU et le SWAP du virtual-host explose et les
# gains/pertes en IO deviennent extrêment aléatoire, c'était une très
# mauvaise idée.
line_separator
# VBox 5.1.14 : utilise le cache sinon trop de blocs fracturés ou corrompus lors
# des sauvegardes et lenteurs excessives d'IO disques.
# Impacte : lors de gros traitement la consommation CPU et du SWAP du virtual-host
# augmente.
# Les temps IOs sont meilleures, mais ne sont pas au niveau des versions précédentes.
exec_cmd VBoxManage storagectl $infra_hostname --name SATA --hostiocache on
LN
fi # [ 0 -eq 1 ]; then

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
exec_cmd "$vm_scripts_path/start_vm $infra_hostname -wait_os=no -dataguard=no"
LN

#	La VM à encore l'IP du master.
exec_cmd wait_server $master_ip
LN

line_separator
info "Add public Iface $if_pub_name, change ip to $infra_ip"
ssh_master	nmcli connection modify			System\\\ $if_pub_name		\
					ipv4.addresses			$infra_ip/$if_pub_prefix	\
					ipv4.dns				$dns_ip						\
					connection.zone			trusted						\
					connection.autoconnect	yes
ssh_master "sed -i 's/^NAME=.*/NAME=$if_pub_name/' $network_scripts/ifcfg-$if_pub_name"
ssh_master "cat $network_scripts/ifcfg-$if_pub_name"
LN

#	Il faut rebooter la VM à cause du changement d'IP.
info "Restart VM $infra_hostname, new network config take effect."
exec_cmd "$vm_scripts_path/reboot_vm $infra_hostname"
LN
exec_cmd wait_server $infra_ip

line_separator
info "Add IP $infra_ip ($infra_hostname) into local know_host."
add_to_known_hosts $infra_ip
LN

info "Create NFS mount points."
ssh_infra "mkdir /mnt/plescripts"
ssh_infra "ln -s /mnt/plescripts ~/plescripts"
ssh_infra "mount ${infra_network}.1:/home/$common_user_name/plescripts /root/plescripts -t nfs -o rw,$nfs_options"
LN

line_separator
ssh_infra "~/plescripts/setup_first_vms/01_prepare_infra_vm.sh"

line_separator
info "Create yum repository"
exec_cmd "~/plescripts/yum/init_infra_repository.sh"
LN

line_separator
ssh_infra "~/plescripts/setup_first_vms/02_update_config.sh"
ssh_infra "~/plescripts/setup_first_vms/03_setup_infra_vm.sh"
LN

line_separator
info "Stop VM $infra_hostname to adjust RAM"
exec_cmd "stop_vm -server=$infra_hostname -dataguard=no"
LN

line_separator
info "Adjust RAM"
exec_cmd VBoxManage modifyvm $infra_hostname --memory $vm_memory_mb_for_infra
LN

line_separator
info "Start VM."
exec_cmd "start_vm $infra_hostname -wait_os=no -dataguard=no"
exec_cmd wait_server $infra_ip
LN

line_separator
info "Remove IP $master_ip & $infra_ip from known_host file of $client_hostname"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh	-ip=${master_ip}		\
														-host=$master_hostname

exec_cmd ~/plescripts/shell/remove_from_known_host.sh	-ip=${infra_ip}			\
														-host=$infra_hostname
LN

line_separator
#	L'équivalence ssh existe déjà.
add_to_known_hosts $infra_hostname
LN

line_separator
info "Check target"
exec_cmd "ssh $infra_conn \"san/check_target.sh\""
LN

script_stop $ME
LN

info "Execute : ./03_install_vm_master.sh"
LN
