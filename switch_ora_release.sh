#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -rel=12.1|12.2"

typeset rel=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-rel=*)
			rel=${1##*=}
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

case $rel in
	12.1)
		release=12.1.0.2
		;;
	12.2)
		release=12.2.0.1
		;;
	*)
		error "rel='$rel' invalid."
		LN
		info "$str_usage"
		LN
		exit 1
esac

typeset	-r	local_cfg="$HOME/plescripts/local.cfg"

[ ! -f $local_cfg ] && touch $local_cfg || true

info "Update oracle_release=$release"
exec_cmd sed -i "/.*oracle_release.*/d" $local_cfg
exec_cmd "echo \"typeset	-r	oracle_release=$release\" >> $local_cfg"
LN
