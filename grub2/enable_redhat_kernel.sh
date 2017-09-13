#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME [-skip_test_infra]

Pour les bases de données le kernel Oracle (UEK) est bien, mais pour le
seveur d'infra $infra_hostname il est préférable d'utiliser le kernel RedHat.
"

typeset test_infra=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-skip_test_infra)
			test_infra=no
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

[ $test_infra == yes ] && must_be_executed_on_server $infra_hostname || true

must_be_user root

kernel=$(grubby --info=ALL|grep -E "^kernel"|grep -v "uek"|head -1|cut -d= -f2)
info "Readhat kernel : $kernel"
LN

info "boot on $kernel"
exec_cmd "grubby --set-default $kernel"
LN

warning "Reboot $infra_hostname"
LN
