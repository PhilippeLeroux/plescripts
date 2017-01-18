#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset		target=graphical
typeset -r	service_name=${infra_hostname}.service
typeset -r	service_file=/usr/lib/systemd/system/${service_name}

typeset -r str_usage=\
"Usage : $ME -target=$target : graphical or multi-user

Create service $service_name to start VM $infra_hostname on startup."

script_banner $ME $*

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
	LN
fi

cat<<EOS>/tmp/$service_name
[Unit]
Description=Start VM $infra_hostname (VirtualBox)
Wants=iscsi.service
After=iscsi.service

[Service]
RemainAfterExit=yes
ExecStart=/usr/bin/su - $USER -c "$HOME/plescripts/virtualbox/start_vm_infra"
ExecStop=/usr/bin/su - $USER -c "$HOME/plescripts/shell/stop_vm $infra_hostname"

[Install]
WantedBy=${target}.target
EOS

exec_cmd sudo mv /tmp/$service_name $service_file
exec_cmd sudo systemctl enable $service_name
exec_cmd sudo systemctl start $service_name
LN
