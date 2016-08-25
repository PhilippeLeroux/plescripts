#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "Running : $ME $*"

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

typeset		vbox_running=no	#	Converne VirtualBox

typeset		infra_running=no
typeset	-a	vm_list
typeset	-i	vm_count=0
while read vm_name rem
do
	if [ "$vm_name" == \"$infra_hostname\" ]
	then
		infra_running=yes
	elif [ x"$vm_name" != x ]
	then
		vm_list[$vm_count]=$vm_name
		vm_count=vm_count+1
	fi
done<<<"$(VBoxManage list runningvms)"

line_separator
info "Save state for running VMs."
info "    $vm_count VMs running : ${vm_list[@]}"
for i in $( seq 0 $(( vm_count-1 )) )
do
	exec_cmd -c "VBoxManage controlvm ${vm_list[$i]}  savestate" &
	LN
done
LN

if [ $vm_count -ne 0 ]
then
	info "Wait all VMs...."
	wait
	LN
fi

[ $infra_running == yes ] && exec_cmd -c "VBoxManage controlvm $infra_hostname savestate" && LN

line_separator
exec_cmd "sudo systemctl stop vboxdrv"
LN
pid_vboxmanager=$(ps -ef|grep [/]usr/lib/virtualbox/VirtualBox | tr -s [:space:] | cut -d' ' -f2)
if [ x"$pid_vboxmanager" != x ]
then
	vbox_running=yes
	info "Stop VirtualBox Manager : "
	exec_cmd kill -1 $pid_vboxmanager
	info -n "Tempo : "; pause_in_secs 2; LN
	pid_vboxmanager=$(ps -ef|grep [/]usr/lib/virtualbox/VirtualBox | tr -s [:space:] | cut -d' ' -f2)
	if [ x"$pid_vboxmanager" != x ]
	then
		exec_cmd kill -15 $pid_vboxmanager
		info -n "Tempo : "; pause_in_secs 2; LN
		pid_vboxmanager=$(ps -ef|grep [/]usr/lib/virtualbox/VirtualBox | tr -s [:space:] | cut -d' ' -f2)
		if [ x"$pid_vboxmanager" != x ]
		then
			error "Cannot stop VirtualBox Manager."
			exit 1
		fi
	fi
fi
exec_cmd "sudo systemctl start vboxdrv"
info -n "Tempo : "; pause_in_secs 2; LN
LN

line_separator
exec_cmd "~/plescripts/virtualbox/create_iface.sh -force_iface_name=vboxnet1"
LN

line_separator
exec_cmd "sudo ifconfig"
LN

if [ $infra_running == yes ]
then
	line_separator
	info "Start $infra_hostname"
	exec_cmd -c "VBoxManage startvm $infra_hostname --type headless"
	LN
fi

line_separator
info "Start $vm_count VMs"
for i in $( seq 0 $(( vm_count-1 )) )
do
	exec_cmd -c "VBoxManage startvm ${vm_list[$i]} --type headless"
done

if [ $vbox_running == yes ]
then
	line_separator
	info "Run VirtualBox manager."
	nohup VirtualBox > /tmp/vv.nohup 2>&1 &
fi
