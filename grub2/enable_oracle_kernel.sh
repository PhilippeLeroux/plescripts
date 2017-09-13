#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	[-version=version] default latest

	Print all version with list_kernel.sh

	Generate grub config file.
"

typeset version=latest

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

if [ "$version" == latest ]
then # Le premier kernel UEK est celui à utiliser.
	info "Enable latest kernel"
	UEK=$(grubby --info=ALL|grep -E "kernel.*uek.*"|head -1|cut -d= -f2)
	LN
else
	[[ "$version" != *el7uek ]] && version="${version}.el7uek" || true
	info "Enable kernel $version"
	UEK=$(grubby --info=ALL|grep -E "kernel.*${version}"|head -1|cut -d= -f2)
	if [ x"$UEK" == x ]
	then
		LN
		warning "Kernel '$version' not installed."
		exec_cmd "yum -y -q install kernel-uek-${version}"
		LN
		UEK="/boot/vmlinuz-${version}"
	else
		LN
	fi
fi

info "boot on $UEK"
exec_cmd "grubby --set-default $UEK"
LN

warning "Need reboot."
LN
