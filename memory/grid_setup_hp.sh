#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "Running : $ME $*"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

if [[ x"$ORACLE_SID" == x || "$ORACLE_SID" == NOSID ]]
then
	error "ORACLE_SID undef."
	exit 1
fi

function slqcmd_setup_memory_hpages
{
	to_exec "alter system set memory_target=0 scope=spfile sid='*';"
	to_exec "alter system set memory_max_target=0 scope=spfile sid='*';"
	to_exec "alter system set sga_target=$hack_asm_memory scope=spfile sid='*';"
}

sqlplus_asm_cmd "$(slqcmd_setup_memory_hpages)"
