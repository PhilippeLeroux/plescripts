#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -start|-stop"

typeset action=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-start)
			action=start
			shift
			;;

		-stop)
			action=stop
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

[ $action = undef ] && error "$str_usage" && exit 1

function start_db
{
	typeset -r OSID=$1

	fake_exec_cmd "startup $OSID"
	ORAENV_ASK=NO
	ORACLE_SID=$OSID
	sqlplus -s sys/$oracle_password as sysdba<<EOS
	startup
EOS
	unset ORAENV_ASK
}

function stop_db
{
	typeset -r OSID=$1

	fake_exec_cmd "shutdown $OSID"
	ORAENV_ASK=NO
	ORACLE_SID=$OSID
	sqlplus -s sys/$oracle_password as sysdba<<EOS
	shutdown immediate
EOS
	unset ORAENV_ASK
}

exec_cmd lsnrctl $action
LN

cat /etc/oratab | grep -E "^[A-Z].*" |\
while IFS=':' read OSID OHOME MANAGED
do
	[[ $MANAGED = Y && $action = start ]] && start_db $OSID || stop_db $OSID
done
