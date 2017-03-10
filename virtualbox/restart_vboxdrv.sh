#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset		infra_running=no	# yes si le serveur d'infra est démarré.
typeset	-a	vm_list				# contiendra le nom de toutes les VMs démarrées
								# sauf le nom du serveur d'infra.

while read vm_name rem
do
	if [ "$vm_name" == \"$infra_hostname\" ]
	then
		infra_running=yes
	elif [ x"$vm_name" != x ]
	then
		vm_list+=( $vm_name )
	fi
done<<<"$(VBoxManage list runningvms)"

typeset -ri	vm_count=${#vm_list[@]}

line_separator
info "Stop running VMs."
info "    $vm_count VMs running : ${vm_list[@]}"
for vm in ${vm_list[*]}
do
	exec_cmd stop_vm $vm &
	LN
done
LN

if [ $vm_count -ne 0 ]
then
	info "Wait all VMs...."
	wait
	LN
fi

if [ $infra_running == yes ]
then
	exec_cmd stop_vm $infra_hostname
	LN
fi

line_separator
exec_cmd "sudo systemctl stop vboxdrv"
LN

timming 8
LN

exec_cmd "sudo systemctl start vboxdrv"
LN

timming 2
LN

line_separator
exec_cmd "~/plescripts/virtualbox/create_iface.sh -force_iface_name=$hostifname"
LN

if [ $infra_running == yes ]
then
	line_separator
	info "Start $infra_hostname"
	exec_cmd start_vm $infra_hostname
	LN
fi

line_separator
exec_cmd "sudo ifconfig"
LN

if [ $vm_count -ne 0 ]
then
	line_separator
	info "Start $vm_count VMs"
	for vm in ${vm_list[*]}
	do
		exec_cmd start_vm $vm
		LN
	done
fi
