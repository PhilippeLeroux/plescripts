#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -i max_latency_ms=10

typeset -r str_usage=\
"Usage :
$ME
	[-max_latency_ms=$max_latency_ms]
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-max_latency_ms=*)
			max_latency_ms=${1##*=}
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

script_banner $ME $*

must_be_user oracle

exit_if_ORACLE_SID_not_defined

function sql_calibrate_io
{
	set_sql_cmd @calibrate_io.sql $max_latency_ms
	set_sql_cmd exit
}

sqlplus_cmd "$(sql_calibrate_io)"
