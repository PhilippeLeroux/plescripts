#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	Generate grub config file.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
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

#ple_enable_log

script_banner $ME $*

info "Generate grub config file"
exec_cmd grub2-mkconfig -o /boot/grub2/grub.cfg
LN

info "Search kernel UEK"
#	boot sur le noyau 3.10, alors que :
#	$ grub2-editenv list
#	saved_entry=Oracle Linux Server 7.3, with Unbreakable Enterprise Kernel 3.8.13-118.15.1.el7uek.x86_64

#	Le premier kernel UEK est celui à utiliser.
UEK=$(grep -E "^menuentry.*Unbreakable Enterprise Kernel.*" /boot/grub2/grub.cfg | cut -d\' -f2 | head -1)
info "boot on $UEK"
#	C'est déjà celui par défaut, mais il faut quand même le préciser.
exec_cmd "grub2-set-default '$UEK'"
LN

info "Take effect after reboot."
LN
