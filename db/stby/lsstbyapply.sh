#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
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

exit_if_ORACLE_SID_not_defined

if [ $(dataguard_config_available) == no ]
then
	error "No Dataguard config."
	LN
	exit 1
fi

typeset	-a	physical_list
typeset	-a	stby_server_list
load_stby_database

for physical_name in ${physical_list[*]}
do
	dgmgrl -silent -echo sys/$oracle_password "show database ${physical_name}"
done
