#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -host=<str>"

script_banner $ME $*

typeset	host=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-host=*)
			host=${1##*=}
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

exit_if_param_undef host "$str_usage"

typeset -r guest_version=$(ssh root@${host} modinfo vboxguest -F version)
typeset -r vbox_version=$(VBoxManage --version | cut -d_ -f1)

line_separator
info "VirtualBox version : $vbox_version"
info "vboxguest version  : $guest_version"

if [ "$guest_version" == "$vbox_version" ]
then
	info "Le module des 'Guest Additions' est à jour sur $host"
	LN
	exit 0
fi

info "Le module des 'Guest Additions' n'est pas à jour sur $host"
LN

ssh -t root@${host}<<EOS
KV=\$(uname -r)
if echo "$KV" | grep -q "uek"
then
	rpm_kernel="kernel-devel-\$KV"
else
	rpm_kernel="kernel-uek-devel-\$KV"
fi
echo "yum -y install deltarpm gcc \$rpm_kernel"
yum -y install deltarpm gcc \$rpm_kernel

[ ! -d /media/cdrom ] && mkdir /media/cdrom || true

echo "mount /dev/cdrom /media/cdrom"
mount /dev/cdrom /media/cdrom

echo "cd /media/cdrom && ./VBoxLinuxAdditions.run"
cd /media/cdrom && ./VBoxLinuxAdditions.run
EOS
[ $? -ne 0 ] && exit 1 || true
LN
exec_cmd "$vm_scripts_path/stop_vm -server=$host -wait_os"
~/plescripts/shell/wait_server $host
LN
