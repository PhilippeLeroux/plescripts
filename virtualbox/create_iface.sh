#!/bin/bash
#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-force_iface_name=str]"

info "$ME $@"

typeset force_iface_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-force_iface_name=*)
			force_iface_name=${1##*=}
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

function config_iface
{
	info "Setup Iface $iface_name"
	exec_cmd -c "VBoxManage hostonlyif ipconfig $iface_name --ip ${infra_network}.1"
}

while [ 0 -eq 0 ]	#	For ever
do
	typeset iface_name=$(VBoxManage hostonlyif create | tail -1 | sed "s/.*'\(.*\)'.*$/\1/g")
	[ $? -ne 0 ] && exit 1

	if [ $force_iface_name == undef ]
	then
		config_iface
		exit 0
	else
		if [ $force_iface_name == $iface_name ]
		then
			config_iface
			exit $?
		else
			typeset -i iface_no=${iface_name:${#iface_name}}
			typeset -i force_iface_no=${force_iface_name:${#force_iface_name}}
			[ $force_iface_no -ge $iface_no ] && exit 1
		fi
	fi
done
