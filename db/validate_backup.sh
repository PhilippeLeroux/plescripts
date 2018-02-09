#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
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

info "Validate backup."
LN

exec_cmd "rman target=sys/$oracle_password @$HOME/plescripts/db/rman/validate_copy_of_database.rman"
LN

exec_cmd "rman target=sys/$oracle_password @$HOME/plescripts/db/rman/validate_archivelog.rman"
LN
