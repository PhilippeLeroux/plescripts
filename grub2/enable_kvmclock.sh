#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
Supprime les options no-kvmclock no-kvmclock-vsyscall
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

must_be_user root

info "Modify kernel parameter, remove parameters no-kvmclock no-kvmclock-vsyscall"
if ! grep -q "no-kvmclock no-kvmclock-vsyscall" /etc/default/grub
then
	error "Parameter not set."
	exit 1
fi

exec_cmd "sed -i 's/ no-kvmclock no-kvmclock-vsyscall//g' /etc/default/grub"
LN

exec_cmd "~/plescripts/grub2/enable_oracle_kernel.sh"
LN
