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

typeset		update_hostname=no
typeset		update_os=yes

typeset -r str_usage=\
"Usage : $ME
	[-emul]

Flag utilisé quand je créé des master différent test ou autre.
	[-update_hostname]      Met à jour le nom du serveur puis configure le réseau.
	[-update_os=$update_os]	no : aucun package n'est installé et les dépôts locaux ne sont pas configurés.

Création de la VM ${master_hostname}.
	- IP               : $master_ip
	- Interface réseau : $hostifname

Ce script doit être exécuté uniquement lorsque la VM d'infra est prête.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-update_os=*)
			update_os=${1##*=}
			shift
			;;

		-update_hostname)
			update_hostname=yes
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

function master_ssh
{
	typeset continue=no
	while [ 0 -eq 0 ]	# forever
	do
		case "$1" in
			"-c")
				continue=yes
				shift
				;;

			*)
				break
				;;
		esac
	done

	debug "ssh connection from $(hostname -s) to $master_ip"
	[ "$DEBUG_MODE" == ENABLE ] && ED="export DEBUG_MODE=ENABLE;"
	exec_cmd -c "ssh -t root@${master_ip} \"$ED$@\""
	typeset -ri ret=$?
	if [ $ret -ne 0 ]
	then
		[ $continue == no ] && exit 1 || return $ret
	else
		return 0
	fi
}

function update_hostname_and_network
{
	ssh root@${infra_hostname} "~/plescripts/dns/test_ip_node_used.sh $master_ip_node"
	if [ $? -ne 0 ]
	then
		error "IP $master_ip in used."
		LN
		exit 1
	fi

	info "Backup de ~/.ssh/known_hosts"
	exec_cmd "cp ~/.ssh/known_hosts ~/.ssh/known_hosts.backup"
	LN

	info "Cleanup :"
	exec_cmd ~/plescripts/shell/remove_from_known_host.sh	\
											-ip=${master_ip}
	LN

	info "Ajout de $master_hostname dans le DNS"
	exec_cmd "ssh -t $infra_conn \"dns/add_server_2_dns.sh -name=$master_hostname -ip_node=$master_ip_node\""
	LN

	info "Restauration de ~/.ssh/known_hosts"
	exec_cmd "mv ~/.ssh/known_hosts.backup ~/.ssh/known_hosts"
	LN

	info "Le script peut être relancé."
	LN

	exit 1
}

[ $update_hostname == yes ] && update_hostname_and_network || true

ple_enable_log -params $PARAMS

script_start

if ! ssh root@K2 "dns/show_dns.sh | grep $master_hostname >/dev/null"
then
	LN
	warning "$master_hostname n'est pas dans le DNS."
	LN
	# la fonction fait un exit 1
	update_hostname_and_network
fi

#	La VM ne doit pas être démarrée.
stop_vm $master_hostname
LN

line_separator
info "Cleanup :"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh	\
								-host=${master_hostname} -ip=${master_ip}
LN

line_separator
#	Peu importe le rôle de la VM - standalone ou nœud RAC - ajout d'une 3e NIC.
info "Add NIC for RAC interco :"
exec_cmd VBoxManage modifyvm $master_hostname --nic3 intnet
exec_cmd VBoxManage modifyvm $master_hostname --nictype3 virtio
exec_cmd VBoxManage modifyvm $master_hostname --cableconnected3 on
LN

exec_cmd "$vm_scripts_path/start_vm $master_hostname -lsvms=no"
LN
wait_server $master_ip
LN

line_separator
add_to_known_hosts $master_hostname
LN

exec_cmd -c ~/plescripts/ssh/test_ssh_equi.sh -user=root -server=$master_hostname
if [ $? -ne 0 ]
then
	LN

	confirm_or_exit -reply_list=CR "root password for VM $master_hostname will be asked. Press enter to continue."
	exec_cmd ~/plescripts/ssh/make_ssh_user_equivalence_with.sh	\
											-user=root -server=$master_hostname
fi
LN

line_separator
#	Ajoute le DNS ce qui permet de monter le répertoire plescripts depuis le
#	virtual-host.
info "Add DNS"
master_ssh "echo \"DNS1=$dns_ip\" >> $if_pub_file"
master_ssh "systemctl restart network"
LN

line_separator
#	Le DNS étant accessible, le montage peut être fait.
info "Mount plescripts from $client_hostname on /mnt/plescripts."
master_ssh mkdir /mnt/plescripts
master_ssh "echo \"$client_hostname:/home/$common_user_name/plescripts /mnt/plescripts nfs rw,$rw_nfs_options,comment=systemd.automount 0 0\" >> /etc/fstab"
master_ssh mount /mnt/plescripts
master_ssh "ln -s /mnt/plescripts ~/plescripts"
LN

#	Le montage étant fait les scripts sont disponibles.
master_ssh "~/plescripts/setup_first_vms/01_prepare_master_vm.sh -update_os=$update_os"
LN

line_separator
exec_cmd "$vm_scripts_path/stop_vm $master_hostname"
exec_cmd VBoxManage modifyvm $master_hostname --memory 1024
LN

if [ $update_os == yes ]
then
	info "Server $master_hostname ready."
	LN

	info "Create BDD server : https://github.com/PhilippeLeroux/plescripts/wiki/Create-servers"
	LN
else
	exec_cmd "$vm_scripts_path/start_vm $master_hostname"
	LN

	info "Server $master_hostname ready."
	LN

	warning "Pas d'accés internet, pas de dépôts locaux, donc pas de nfs, d'iSCSI."
	LN
fi

script_stop $ME
