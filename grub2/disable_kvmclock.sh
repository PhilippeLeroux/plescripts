#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
Modifie grub2 pour démarrer le kernel avec les options no-kvmclock no-kvmclock-vsyscall
Pour le pourquoi du comment voir la documentation ntp/readme.md
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

info "Modify kernel parameter, add parameters no-kvmclock no-kvmclock-vsyscall"
if grep -q "no-kvmclock no-kvmclock-vsyscall" /etc/default/grub
then
	error "Parameter already set."
	exit 1
fi

exec_cmd cp /etc/default/grub /etc/default/grub.$(date +%d)
exec_cmd "sed -i 's/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 no-kvmclock no-kvmclock-vsyscall\"/' /etc/default/grub"
LN

exec_cmd "~/plescripts/grub2/grub2_mkconfig.sh"
LN
