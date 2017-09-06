#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME [-emul]
	Database & crs are stopped, after update server is bounced.
	Script must be executed on all members of cluster dataguard or RAC.
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

#	Lors d'une mise à jour la configuration d'oracleasm a été perdu.
#	Donc elle est refaite par précaution.
function update_oracle_asm_configuration
{
	if command_exists oracleasm
	then
		line_separator
		info "Configure oracleasm :"
		exec_cmd "~/plescripts/oracle_preinstall/configure_oracleasm.sh"
		LN
	fi
}

function reboot_server
{
	line_separator
	info "Reboot"
	exec_cmd -c systemctl reboot
	LN
}

function execute_yum_update
{
	line_separator
	info "update :"
	exec_cmd "yum -y update"
	LN
}

function check_module_vboxguest
{
	typeset -r guest=$(modinfo vboxguest -F vermagic 2>/dev/null|cut -d\  -f1)

	if [ x"$guest" != x ]
	then
		warning "Module vboxguest installed."
		warning "From $client_hostname execute :"
		warning "$ cd ~/plescripts/virtualbox/guest"
		warning "$ ./test_guestadditions.sh -host=$(hostname -s)"
		LN
	fi
}

function update_standalone_server
{
	info "Update : $gi_current_node"
	LN

	if [ $crs_used == yes ]
	then
		line_separator
		info "Stop Grid Infra :"
		exec_cmd "crsctl stop has"
		LN
	else
		line_separator
		info "Stop database :"
		exec_cmd "su - oracle -c '~/plescripts/db/stop_db.sh'"
		LN
	fi

	execute_yum_update

	update_oracle_asm_configuration

	check_module_vboxguest

	reboot_server
}

function update_cluster_server
{
	info "Update : $gi_current_node $gi_node_list"
	LN

	line_separator
	info "Stop crs on node $gi_current_node :"
	exec_cmd "crsctl stop crs"
	LN

	execute_yum_update

	update_oracle_asm_configuration

	line_separator
	info "Si OCFS2 est utilisé, mettre à jour la configuration."
	LN
	info "Mettre à jour les noeuds $gi_node_list"
	LN

	check_module_vboxguest

	reboot_server
}

must_be_user root

ple_enable_log -params $PARAMS

if command_exists crsctl
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

if ! rpm_update_available -show
then
	info "No update."
	exit 0
fi

confirm_or_exit "Update available, update"

if [ $gi_count_nodes -eq 1 ]
then
	update_standalone_server
else
	update_cluster_server
fi
