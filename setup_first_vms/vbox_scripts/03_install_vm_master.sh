#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME [-emul]

Ce script doit être exécuté uniquement lorsque la VM d'infra est prête.
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

ple_enable_log

script_banner $ME $*

script_start

#	La VM ne doit pas être démarrée.
stop_vm $master_hostname -dataguard=no
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

exec_cmd "$vm_scripts_path/start_vm $master_hostname -dataguard=no"
LN
wait_server $master_ip
LN

line_separator
add_to_known_hosts $master_hostname
exec_cmd -c ~/plescripts/ssh/test_ssh_equi.sh -user=root -server=$master_hostname
if [ $? -ne 0 ]
then
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
master_ssh "echo \"$client_hostname:/home/$common_user_name/plescripts /mnt/plescripts nfs rw,$nfs_options,comment=systemd.automount 0 0\" >> /etc/fstab"
master_ssh mount /mnt/plescripts
master_ssh "ln -s /mnt/plescripts ~/plescripts"
LN

#	Le montage étant fait les scripts sont disponibles.
master_ssh "~/plescripts/setup_first_vms/01_prepare_master_vm.sh"
LN

exec_cmd "$vm_scripts_path/stop_vm $master_hostname -dataguard=no"
LN

info "Server $master_hostname ready."
LN

info "Create BDD server : https://github.com/PhilippeLeroux/plescripts/wiki/Create-servers"
LN

script_stop $ME
