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

exit_if_param_invalid action "start stop" "$str_usage"

function start_db
{
	typeset -r OSID=$1

	ORACLE_SID=$OSID
	ORAENV_ASK=NO . oraenv
	fake_exec_cmd "sqlplus -s sys/$oracle_password as sysdba"
	sqlplus -s sys/$oracle_password as sysdba<<EOS
	prompt startup
	startup
EOS
}

function stop_db
{
	typeset -r OSID=$1

	ORACLE_SID=$OSID
	ORAENV_ASK=NO . oraenv
	fake_exec_cmd "sqlplus -s sys/$oracle_password as sysdba"
	sqlplus -s sys/$oracle_password as sysdba<<EOS
	prompt shutdown immediate
	shutdown immediate
EOS
}

exec_cmd -c lsnrctl $action
LN

cat /etc/oratab | grep -E "^[A-Z].*" |\
while IFS=':' read OSID OHOME MANAGED
do
	if [ $MANAGED = Y ]
	then
		info "$action database $OSID"
		[ $action = start ] && start_db $OSID || stop_db $OSID
	else
		info "$OSID ignored."
	fi
done
