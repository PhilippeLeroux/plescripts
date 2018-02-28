#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
$ME
	-version=version|latest|redhat

Print all version with list_kernel.sh

Generate grub config file.

For $infra_hostname server setup IO scheduler $infra_io_scheduler
"

typeset version=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-version=*)
			version=${1##*=}
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

exit_if_param_undef version "$str_usage"

must_be_user root

if grubby --default-kernel | grep -E "el7uek"
then
	typeset	-r	cur_kernel_is=UEK
else
	typeset	-r	cur_kernel_is=RHEL
fi

case "$version" in
	latest) # Le premier kernel UEK est celui à utiliser.
		info "Enable latest kernel"
		kernel=$(grubby --info=ALL|grep -E "kernel.*uek.*"|head -1|cut -d= -f2)
		LN
		;;

	redhat)
		kernel=$(grubby --info=ALL|grep -E "^kernel"|grep -v "uek"|head -1|cut -d= -f2)
		info "Enable Redhat kernel : $kernel"
		LN
		;;

	*)
		[[ "$version" != *el7uek ]] && version="${version}.el7uek" || true
		info "Enable kernel $version"
		kernel=$(grubby --info=ALL|grep -E "kernel.*${version}"|head -1|cut -d= -f2)
		if [ x"$kernel" == x ]
		then
			LN
			warning "Kernel '$version' not installed."
			exec_cmd "yum -y -q install kernel-uek-${version}"
			LN
			kernel="/boot/vmlinuz-${version}"
		else
			LN
		fi
		;;
esac

info "Next boot on $kernel"
exec_cmd "grubby --set-default $kernel"
LN

if [ $(hostname -s) == $infra_hostname ]
then
	if [ $version == redhat ]
	then
		exec_cmd "$HOME/plescripts/grub2/setup_or_remove_elevator.sh -kernel=RHEL"
	else
		[ $cur_kernel_is == RHEL ] && params=" -force" || true
		exec_cmd "$HOME/plescripts/grub2/setup_or_remove_elevator.sh -kernel=UEK$params"
	fi
fi
