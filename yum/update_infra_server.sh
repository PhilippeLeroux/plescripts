#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME [-emul]
	Update server $infra_hostname
	Ensure Redhat kernel is enable after update.
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

must_be_executed_on_server $infra_hostname

must_be_user root

ple_enable_log -params $PARAMS

if ! rpm_update_available -show
then
	info "No update."
	exit 0
fi

confirm_or_exit "Update available, update"

line_separator
exec_cmd yum -y update
LN

line_separator
if [ "$infra_kernel_version" == redhat ]
then
	exec_cmd "~/plescripts/grub2/enable_kernel.sh -version=redhat"
	LN
else
	exec_cmd "~/plescripts/grub2/setup_or_remove_elevator.sh -kernel=UEK"
	LN
fi

line_separator
info "Workaround : SELinux settings can be lost after update."
exec_cmd ~/plescripts/dns/setup_SELinux.sh

line_separator
warning "From $client_hostname execute : reboot_vm $infra_hostname"
LN
