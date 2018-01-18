#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-ri	nr_cpus=$(grep -E "^processor" /proc/cpuinfo | wc -l)
typeset	-ri	parallel_min_servers=$(( nr_cpus * 2 ))
typeset	-ri	parallel_max_servers=$(( nr_cpus * 4 ))

typeset	-r	str_usage=\
"Usage
$ME
	-db=name
	[-reset] reset parameters parallel_min_servers & parallel_max_servers
	
set parallel_min_servers = $parallel_min_servers
set parallel_max_servers = $parallel_max_servers
"

typeset		db=undef
typeset		reset=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-reset)
			reset=yes
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

# $1 min
# $2 max
function sql_set_parallel_servers
{
	set_sql_cmd "alter system set parallel_min_servers=$1 scope=both sid='*';"
	set_sql_cmd "alter system set parallel_max_servers=$2 scope=both sid='*';"
}

function sql_reset_parallel_servers
{
	set_sql_cmd "alter system reset parallel_min_servers scope=both sid='*';"
	set_sql_cmd "alter system reset parallel_max_servers scope=both sid='*';"
}

exit_if_param_undef db	"$str_usage"

must_be_user oracle

exit_if_ORACLE_SID_not_defined

if [ $reset == yes ]
then
	sqlplus_cmd "$(sql_reset_parallel_servers)"
else
	sqlplus_cmd "$(sql_set_parallel_servers $parallel_min_servers $parallel_max_servers)"
fi
