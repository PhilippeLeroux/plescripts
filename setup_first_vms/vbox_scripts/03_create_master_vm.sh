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

function infra_ssh
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

	exec_cmd -c "ssh -t root@${infra_network}.${master_ip_node} \"$@\""
	typeset -ri ret=$?
	if [ $ret -ne 0 ]
	then
		[ $continue == no ] && exit 1 || return $ret
	else
		return 0
	fi
}

typeset -r script_start_at=$SECONDS

line_separator
info "Ménage :"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${master_name}
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

confirm_or_exit -reply_list=CR "Le mot de passe root sera demandé. Press enter to continue."
exec_cmd ~/plescripts/shell/make_ssh_user_equivalence_with.sh -user=root -server=${master_ip}
LN

if [ $type_shared_fs == vbox ]
then
	line_separator
	infra_ssh "echo DNS1=$infra_ip >> $if_pub_file"
	infra_ssh "echo GATEWAY=$infra_ip >> $if_pub_file"
	infra_ssh "systemctl restart network"
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
info "Création du répertoire plescripts."
infra_ssh -c "mkdir /mnt/plescripts"
LN

info "Montage provisoire de /mnt/plescripts"
case $type_shared_fs in
	vbox)
		infra_ssh "mount -t vboxsf plescripts /mnt/plescripts"
		;;

	nfs)
		infra_ssh "mount ${infra_network}.1:/home/kangs/plescripts /mnt/plescripts -t nfs -o rw,$nfs_options"
		;;
esac

infra_ssh "ln -s /mnt/plescripts ./plescripts"
LN

infra_ssh "~/plescripts/setup_first_vms/02_update_config.sh"
infra_ssh "~/plescripts/setup_first_vms/03_setup_infra_or_master.sh -role=master"
LN

exec_cmd "$vm_scripts_path/stop_vm $master_name"
LN

info "Le serveur $master_name est prêt."
LN

info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
