#!/bin/ksh
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
	exec_cmd "ssh root@${infra_network}.${master_ip_node} \"$@\""
}

line_separtor
info "Ménage :"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${infra_network}.${master_ip_node}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=orclmaster
LN

case $type_shared_fs in
	vbox)
		exec_cmd VBoxManage sharedfolder add $master_name --name "plescripts" --hostpath "$HOME/plescripts --automount"
		LN
		;;
esac

exec_cmd "$vm_scripts_path/start_vm $master_name"
LN
wait_server ${infra_network}.${master_ip_node}
LN

exec_cmd ~/plescripts/shell/connections_ssh_with.sh -user=root -server=${master_ip}
LN

if [ $type_shared_fs == vbox ]
then
	line_separator
	run_ssh "echo DNS1=$infra_ip >> $if_pub_file"
	run_ssh "echo GATEWAY=$infra_ip >> $if_pub_file"
	run_ssh "systemctl restart network"
	LN

	line_separator
	exec_cmd "$vm_scripts_path/compile_guest_additions.sh -host=${master_ip}"
	LN
	exec_cmd "$vm_scripts_path/stop_vm $master_name"
	info -n "Temporisation : "; pause_in_secs 20; LN
	exec_cmd "$vm_scripts_path/start_vm $master_name"
	wait_server $master_name
	[ $? -ne 0 ] && exit 1
fi

line_separator
info "Prépartation du répertoire plescripts."
run_ssh "mkdir /mnt/plescripts"
LN

info "Montage provisoire de /mnt/plescripts"
case $type_shared_fs in
	vbox)
		run_ssh "mount -t vboxsf plescripts /mnt/plescripts"
		;;

	nfs)
		run_ssh "mount 192.170.100.1:/home/kangs/plescripts /mnt/plescripts"
		;;
esac

run_ssh "ln -s /mnt/plescripts ./plescripts"
LN

run_ssh "~/plescripts/setup_first_vms/02_update_config.sh"
run_ssh "~/plescripts/setup_first_vms/03_setup_infra_or_master.sh -role=master"
LN

exec_cmd "$vm_scripts_path/stop_vm $master_name"
LN

info "Le serveur $master_name est prêt."

