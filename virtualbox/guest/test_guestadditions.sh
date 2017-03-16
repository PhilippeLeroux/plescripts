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

typeset		guest_version=$(ssh root@${host} 'modinfo vboxguest -F version|cut -d\  -f1')
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

warning "Le module des Guest Additions n'est pas à jour sur $host"
LN
info "Exécuter le script :"
info "    - ./attach_iso_guestadditions.sh -vm_name=$host"
LN

info "Exécuter sur $host :"
info "    - cd ~/plescripts/virtualbox/guest"
info "    - ./install_guestadditions.sh"
LN
exit 1
