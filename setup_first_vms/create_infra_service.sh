#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset		target=graphical
typeset		start=no
typeset	-r	service_name=${infra_hostname}.service
typeset	-r	service_file=/usr/lib/systemd/system/${service_name}

typeset -r str_usage=\
"Usage :
$ME
	-target=$target : graphical or multi-user
	[-start] to start $infra_hostname on boot, by default only
	stop $infra_hostname when $client_hostname stop.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-target=*)
			target=${1##=*}
			shift
			;;

		-start)
			start=yes
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

if [ -f $service_file ]
then
	error "${service_name} exists."
	LN
	exec_cmd systemctl status ${service_name}
	LN
	info "To stop :"
	info "\tsudo systemctl stop ${service_name}"
	info "\tsudo systemctl disable ${service_name}"
	info "\tsudo rm $service_file"
	confirm_or_exit "Do actions"
	exec_cmd sudo systemctl stop ${service_name}
	exec_cmd sudo systemctl disable ${service_name}
	exec_cmd sudo rm $service_file
	LN
fi

cat<<EOS>/tmp/$service_name
[Unit]
Description=VM $infra_hostname (VirtualBox)
Wants=iscsi.service
After=iscsi.service

[Service]
RemainAfterExit=yes
EOS

if [ $start == yes ]
then
	echo "ExecStart=/usr/bin/su - $USER -c \"/usr/bin/VBoxManage startvm $infra_hostname --type headless\"" >> /tmp/$service_name
fi

cat<<EOS>>/tmp/$service_name
ExecStop=/usr/bin/su - $USER -c "$HOME/plescripts/shell/stop_vm $infra_hostname"

[Install]
WantedBy=${target}.target
EOS

exec_cmd sudo mv /tmp/$service_name $service_file
exec_cmd sudo systemctl enable $service_name
exec_cmd sudo systemctl start $service_name
LN

if [ $start == no ]
then
	info "Service only stop $infra_hostname"
	info "add flag -start if you want start $infra_hostname on boot."
	LN
fi
