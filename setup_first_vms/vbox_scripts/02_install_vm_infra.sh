#!/bin/bash
# vim: ts=4:sw=4:ft=sh
# ft=sh car la colorisation ne fonctionne pas si le nom du script commence par
# un n°

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME
	[-emul]

Création de la VM ${infra_hostname}.
	- IP               : $infra_ip
	- Interface réseau : $hostifname
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

ple_enable_log -params $PARAMS

script_start

if [[ $disks_hosted_by == san && "$san_disk" != "vdi" ]]
then
	line_separator
	typeset -i sd_errors=0
	info -n "$san_disk exists "
	if [ -b "$san_disk" ]
	then
		info -f "[$OK]"
		LN
	else
		info -f "[$KO]"
		LN
		exit 1
	fi

	typeset -r device_group=$(ls -l "$san_disk" | cut -d\  -f4)
	info "$san_disk in group : $device_group"
	info -n "$common_user_name member of group : $device_group "
	if id | grep -q $device_group
	then
		info -f "[$OK]"
		LN
	else
		info -f "[$KO] add $common_user_name to group $device_group"
		exec_cmd sudo usermod -a -G $device_group $common_user_name
		LN
		error "Disconnect & connect user $common_user_name"
		LN
		exit 1
	fi

	line_separator
	info "Clear $san_disk"
	exec_cmd "sudo dd if=/dev/zero of=$san_disk bs=$((1024*1024)) count=1024"
	LN
fi

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

if master_ip_is_pingable
then
	#	La VM master vient d'être créée, elle est démarrée.
	line_separator
	confirm_or_exit -reply_list=CR "root password for VM $master_hostname will be asked. Press enter to continue."
	exec_cmd "make_ssh_user_equivalence_with.sh -user=root -server=$master_ip"

	info "Stop VM $master_hostname"
	#	Normalement la VM est démarrée, si ce n'est pas le cas erreur mais continue.
	exec_cmd stop_vm -server=$master_hostname
	LN
else
	#	Je considère que l'équivalence est faite et que je recommence un test de
	#	création de la VM d'infra.
	exec_cmd start_vm $master_hostname -wait_os=no -lsvms=no
	exec_cmd wait_server $master_ip
	add_to_known_hosts $master_ip
	exec_cmd stop_vm -server=$master_hostname
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
exec_cmd VBoxManage modifyvm $infra_hostname --bridgeadapter3 "$if_net_bridgeadapter"
exec_cmd VBoxManage modifyvm $infra_hostname --nictype3 virtio
exec_cmd VBoxManage modifyvm $infra_hostname --cableconnected3 on
LN

line_separator
exec_cmd VBoxManage modifyvm $infra_hostname --cpus 2
LN

if [ 0 -eq 1 ]; then
# --hostiocache on : la CPU et le SWAP du virtual-host explosent et les
# gains/pertes en IO deviennent extrêmement aléatoires, c'était une très
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

if [ $disks_hosted_by == san ]
then
	line_separator
	info "Add disk for SAN storage (targetcli)"
	if [ "$san_disk" == "vdi" ]
	then
		exec_cmd $vm_scripts_path/add_disk.sh					\
						-vm_name=$infra_hostname				\
						-disk_name=asm01_disk01					\
						-disk_mb=$(( $san_disk_size_g * 1024 ))	\
						-mtype=writethrough						\
						-fixed_size
		LN
	else
		exec_cmd $vm_scripts_path/add_raw_disk.sh	\
						-vm_name=$infra_hostname	\
						-disk_name=asm01_disk01		\
						-os_device="$san_disk"

		LN

	fi
fi

line_separator
info "Move $infra_hostname to group Infra"
exec_cmd VBoxManage modifyvm "$infra_hostname" --groups "/Infra"
LN

line_separator
info "Start VM $infra_hostname"
exec_cmd "$vm_scripts_path/start_vm $infra_hostname -wait_os=no -lsvms=no"
LN

#	La VM à encore l'IP du master.
exec_cmd wait_server $master_ip
LN

line_separator
# OL 7.3 affiche le nom en francais, 'System eth0' devient 'Système eth0'
# Lecture du nom de la première connexion.
ssh_master nmcli connection show
conn_name="$(ssh root@${master_ip} "nmcli connection show | nmcli connection show | grep $if_pub_name | cut -d\  -f1-2")"
info "Connection name : $conn_name"
info "Add public Iface $if_pub_name, change ip to $infra_ip"
ssh_master	nmcli connection modify			"'$conn_name'"				\
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
ssh_infra "mount ${infra_network}.1:/home/$common_user_name/plescripts /root/plescripts -t nfs -o rw,$rw_nfs_options"
LN

line_separator
ssh_infra "~/plescripts/setup_first_vms/01_prepare_infra_vm.sh"

line_separator
info "Create yum repository"
exec_cmd "~/plescripts/yum/init_infra_repository.sh -infra_install"
LN

line_separator
ssh_infra "~/plescripts/setup_first_vms/02_update_config.sh"
ssh_infra "~/plescripts/setup_first_vms/03_setup_infra_vm.sh"
LN

line_separator
info "Stop VM $infra_hostname to adjust RAM"
exec_cmd "stop_vm -server=$infra_hostname"
LN

line_separator
info "Adjust RAM"
exec_cmd VBoxManage modifyvm $infra_hostname --memory $vm_memory_mb_for_infra
LN

line_separator
info "Start VM."
exec_cmd "start_vm $infra_hostname -wait_os=no -lsvms=no"
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

script_stop $ME
LN

info "Execute : ./03_install_vm_master.sh"
LN
