#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -host=<str> [-y]"

typeset	host=undef
typeset confirm=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-host=*)
			host=${1##*=}
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

exit_if_param_undef host "$str_usage"

exit_if_cannot_connect_to $host

typeset		guest_version=$(ssh root@${host} 'modinfo vboxguest -F version 2>/dev/null|cut -d\  -f1')
[ x"$guest_version" == x ] && guest_version="not installed" || true
typeset -r	vbox_version=$(VBoxManage --version | cut -d_ -f1)

typeset -r	virtual_host=$(hostname -s)
[ ${#virtual_host} -gt ${#host} ] && max_len=${#virtual_host} || max_len=${#host}

line_separator
info "$(printf "VirtualBox version on %-${max_len}s     : %s" $(hostname -s) "$vbox_version")"
info "$(printf "Guest Addition version on %-${max_len}s : %s" $host "$guest_version")"
LN

if [ "$guest_version" == "$vbox_version" ]
then
	info "Le module des Guest Additions est à jour sur $host"
	LN
	exit 0
fi

if [ "$guest_version" == "not installed" ]
then
	info "Le module des Guest Additions n'est pas installé sur $host"
	LN

	if [ $confirm == yes ]
	then
		confirm_or_exit "Installer"
		LN
	fi
else
	warning "Le module des Guest Additions n'est pas à jour sur $host"
	LN

	if [ $confirm == yes ]
	then
		confirm_or_exit "Mettre à jour"
		LN
	fi
fi

exec_cmd "~/plescripts/virtualbox/guest/attach_iso_guestadditions.sh	\
																-vm_name=$host"
LN

exec_cmd "ssh -t root@$host \
			\"\\\$HOME/plescripts/virtualbox/guest/install_guestadditions.sh\""
LN
