#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/vmlib.sh
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME

Met à jour suse LEAP, stop toutes les VMs avant pour éviter tout problème, en
cas de mise à jour de VBox.
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

#ple_enable_log -params $PARAMS

# Create array vm_running_list
function load_running_vms
{
	typeset	-ga	vm_running_list
	typeset		vm_name

	while read vm_name
	do
		vm_running_list+=( $vm_name )
	done<<<"$(VBoxManage list runningvms|sed "s/^\"\(.*\)\".*$/\1/g")"
	LN
}

load_running_vms

info "Arrêt de ${#vm_running_list[*]} VMs."
LN

for vm_name in ${vm_running_list[*]}
do
	save_vm $vm_name
	LN
done

line_separator
info "Update SUSE"
exec_cmd -c sudo zypper up -y
LN

line_separator
exec_cmd -c sudo zypper ps -s

if [ ${#vm_running_list[*]} -ne 0 ]
then
	line_separator
	confirm_or_exit "Démarrer ${#vm_running_list[*]} VMs"

	for vm_name in ${vm_running_list[*]}
	do
		start_vm $vm_name
		LN
	done
fi
