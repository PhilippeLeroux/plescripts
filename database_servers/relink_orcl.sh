#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME"

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

must_be_user oracle

info "Relinking."
LN

fake_exec_cmd "cd \$ORACLE_HOME/rdbms/admin"
cd $ORACLE_HOME/rdbms/admin
LN

exec_cmd "/usr/bin/make -f $ORACLE_HOME/rdbms/lib/ins_rdbms.mk ioracle"
LN

exec_cmd "/usr/bin/make -f $ORACLE_HOME/rdbms/lib/ins_rdbms.mk irman"
LN

fake_exec_cmd "cd -"
cd -
LN
