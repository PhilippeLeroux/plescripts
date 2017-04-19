#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME exit 1 if $ORACLE_HOME/bin/oracle size == 0"

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

#ple_enable_log

script_banner $ME $*

if [ x"$ORACLE_HOME" == x ]
then
	error "ORACLE_HOME not defined."
	LN
	exit 1
fi

info "Check : $ORACLE_HOME/bin/oracle"
exec_cmd "ls -l $ORACLE_HOME/bin/oracle"
LN

size="$(du -s $ORACLE_HOME/bin/oracle|cut -d\  -f1)"
if [ "$size" == "0" ]
then
	error "Invalide size :"
	LN
	exit 1
fi

exit 0