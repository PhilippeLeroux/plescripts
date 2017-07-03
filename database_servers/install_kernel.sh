#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-version=version    like -version=3.8.13-118.17.5
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

must_be_user root

exit_if_param_undef version	"$str_usage"

# Note : Pourquoi la commande yum list available kernel-uek ne renvoie rien ?

info "Install kernel kernel-uek-${version}.el7uek"
exec_cmd "yum -y -q install kernel-uek-${version}.el7uek"
LN

info "Enable kernel"
exec_cmd "~/plescripts/grub2/grub2_mkconfig.sh -version=$version"
