#!/bin/bash
#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset -r iface_name=$(VBoxManage hostonlyif create | tail -1 | sed "s/.*'\(.*\)'.*$/\1/g")
if [ $? -eq 0 ]
then
	info "Setup Iface $iface_name"
	exec_cmd -c "VBoxManage hostonlyif ipconfig $iface_name --ip ${infra_network}.1"
else
	info "Iface $iface_name exists."
fi
LN
