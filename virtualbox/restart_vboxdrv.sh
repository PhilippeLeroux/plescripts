#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"
typeset	-r	str_usage=\
"Usage :
$ME
	[-y] no confirmation."

typeset		confirm=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-y)
			confirm=no
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
	exec_cmd stop_vm $vm
	LN
done
LN

if [ $infra_running == yes ]
then
	exec_cmd stop_vm $infra_hostname
	LN
fi

typeset	-i	nr_process_killed=0

line_separator
info "Arrêt de Oracle VirtualBox manager"
for sig in 1 15 9
do
	nr_process_killed=0
	while read user pid ppid c stime tt time cmd
	do
		[ x"$pid" == x ] && continue || true

		((++nr_process_killed))
		info "stop process $cmd pid = $pid"
		exec_cmd -c "sudo kill -$sig $pid"
		LN
	done<<<"$(ps -ef|grep -E "/usr/lib/.*[V]irtual.*")"

	[ $nr_process_killed -ne 0 ] && timing 2 && LN || true
done
LN

line_separator
exec_cmd "sudo systemctl stop vboxes"
exec_cmd "sudo systemctl stop vboxdrv"
LN

line_separator
info "Vérifie que plus aucun process n'est actif."
for sig in 15 9
do
	nr_process_killed=0
	while read pid term tt process
	do
		[ x"$pid" == x ] && continue || true

		((++nr_process_killed))
		info "stop process $process pid = $pid"
		exec_cmd -c "sudo kill -$sig $pid"
		LN
	done<<<"$(ps -e|grep [V]Box)"

	[ $nr_process_killed -ne 0 ] && timing 5 && LN || true
done

exec_cmd -c "ps -ef|grep [V]Box"
LN

if [ $confirm == yes ]
then
	confirm_or_exit "Continue"
	LN
fi

exec_cmd "sudo systemctl start vboxdrv"
exec_cmd "sudo systemctl start vboxes"
LN

timing 2
LN

line_separator
exec_cmd "~/plescripts/virtualbox/create_iface.sh -force_iface_name=$hostifname"
LN

if [ $infra_running == yes ]
then
	line_separator
	info "Start $infra_hostname"
	exec_cmd start_vm $infra_hostname -lsvms=no
	LN
fi

line_separator
exec_cmd "sudo ifconfig"

if [ $vm_count -ne 0 ]
then
	line_separator
	info "Start $vm_count VMs"
	for vm in ${vm_list[*]}
	do
		exec_cmd start_vm $vm -lsvms=no -wait_os=no
	done

	# Attend que la dernière VM ait démarré.
	exec_cmd wait_server $vm
	LN
fi

line_separator
exec_cmd lsvms
