#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

Pour les bases de données le kernel Oracle (UEK) est bien, mais pour le
seveur d'infra $infra_hostname il est préférable d'utiliser le kernel RedHat.
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

#ple_enable_log -params $PARAMS

must_be_executed_on_server $infra_hostname

must_be_user root

info "Generate grub config file"
exec_cmd grub2-mkconfig -o /boot/grub2/grub.cfg
LN

kernel=$(grep -E "^menuentry.*with Linux.*" /boot/grub2/grub.cfg | cut -d\' -f2 | head -1)
info "Readhat kernel : $kernel"
LN

info "boot on $kernel"
exec_cmd "grub2-set-default '$kernel'"
LN

warning "Reboot $infra_hostname"
LN
