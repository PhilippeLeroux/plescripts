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

typeset -i count_error=0

case $action in
	stop)
		ps -e|grep tnslsnr | grep -v grep >/dev/null 2>&1
		if [ $? -eq 0 ]
		then
			exec_cmd -c lsnrctl $action
			LN
		fi
		;;

	start)
		exec_cmd -c lsnrctl $action
		[ $? -ne 0 ] && count_error=count_error+1
		LN
		;;
esac

while IFS=':' read OSID OHOME MANAGED
do
	if [ $MANAGED = Y ]
	then
		info "$action database $OSID"
		[ $action == start ] && start_db $OSID || stop_db $OSID
		[ $? -ne 0 ] && count_error=count_error+1
	else
		info "$OSID ignored."
	fi
done<<<"$(cat /etc/oratab | grep -E "^[A-Z].*")"
LN

[ $action == start ] && exec_cmd lsnrctl status


info "$count_error $action failed."
[ $count_error -ne 0 ] && exit 1 || exit 0
