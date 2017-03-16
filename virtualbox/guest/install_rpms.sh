#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME"

script_banner $ME $*

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

kern_ver=$(uname -a|cut -d\  -f3)
rpm_devel=kernel-uek-devel-$kern_ver

# TODO : tester si d'ancien kernel sont installés puis les supprimer.
# Test : test -d /usr/src/kernels/$kern_ver

info "Packages for Guest Additions"
exec_cmd yum -y install gcc $rpm_devel
LN
