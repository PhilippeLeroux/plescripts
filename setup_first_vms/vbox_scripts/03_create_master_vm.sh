#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
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

typeset -r script_start_at=$SECONDS

line_separator
info "Ménage :"
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -host=${master_name}
exec_cmd ~/plescripts/shell/remove_from_known_host.sh -ip=${master_ip}
LN

line_separator
#	Peut importe le rôle de la VM - standalone ou noeud RAC - ajout d'une 3ieme NIC.
info "Ajout d'une carte pour l'interco RAC"
exec_cmd VBoxManage modifyvm $master_name --nic3 intnet
exec_cmd VBoxManage modifyvm $master_name --nictype3 virtio
LN

exec_cmd "$vm_scripts_path/start_vm $master_name"
LN
wait_server ${infra_network}.${master_ip_node}
LN

confirm_or_exit -reply_list=CR "root password will be asked. Press enter to continue."
exec_cmd ~/plescripts/shell/make_ssh_user_equivalence_with.sh -user=root -server=${master_name}
LN

line_separator
info "Configuration du réseau."
master_ssh "echo DNS1=$infra_ip >> $if_pub_file"
master_ssh "echo GATEWAY=$infra_ip >> $if_pub_file"
master_ssh "systemctl restart network"
LN

exec_cmd "~/plescripts/setup_first_vms/01_prepare_master_vm.sh"
master_ssh "~/plescripts/setup_first_vms/02_update_config.sh"
master_ssh "~/plescripts/setup_first_vms/03_setup_master_vm.sh"
LN

exec_cmd "$vm_scripts_path/stop_vm $master_name"
LN

info "Le serveur $master_name est prêt."
LN

info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
