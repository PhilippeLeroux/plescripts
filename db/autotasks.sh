#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -enable|-disable|-status"

typeset action=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-enable)
			action=enable
			shift
			;;

		-disable)
			action=disable
			shift
			;;

		-status)
			action=status
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

exit_if_param_invalid action "status enable disable"	"$str_usage"

typeset	-a	autotask_list=(	"sql tuning advisor"	\
							"auto space advisor"	\
							"auto optimizer stats collection" )

typeset	-r	query="--	Print tasks status
set timin on
col	client_name for a40
select
	status
,	client_name
from
	dba_autotask_client
;"

function task	# $1 action $2 name
{
	typeset -r action="$1"
	typeset -r name="$2"

echo "\
begin
	dbms_auto_task_admin.$action
		(
			client_name	=> '$name'
		,   operation	=> null
		,   window_name	=> null
		);
end;
/
"
}

if [ $action != status ]
then
	for task_name in "${autotask_list[@]}"
	do
		cmd_task="$(task $action "$task_name")"
		info "$action $task_name"
		fake_exec_cmd sqlplus -s sys/$oracle_password as sysdba
		echo "$cmd_task"

		sqlplus -s sys/$oracle_password as sysdba<<-EOSQL
		set timin on
		$cmd_task
		EOSQL
		LN
	done
fi

sqlplus_print_query "$query"
LN
