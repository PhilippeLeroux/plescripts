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

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
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

function drop_primary_cfg
{
	to_exec "alter system reset standby_file_management scope=spfile sid='*';"

	to_exec "alter system reset log_archive_config scope=spfile sid='*';"

	to_exec "alter system reset fal_server scope=spfile sid='*';"

	to_exec "alter system reset log_archive_dest_1 scope=spfile sid='*';"

	to_exec "alter system reset log_archive_dest_2 scope=spfile sid='*';"

	to_exec "alter system reset remote_login_passwordfile scope=spfile sid='*';"

	to_exec "alter system reset db_file_name_convert scope=spfile sid='*';"

	to_exec "alter system reset log_file_name_convert scope=spfile sid='*';"

	to_exec "shutdown immediate"
	to_exec "startup"
}

line_separator
dgmgrl<<EOS 
connect sys/$oracle_password
disable configuration;
remove configuration;
EOS
LN

line_separator
sqlplus sys/$oracle_password as sysdba<<EOS
@drop_standby_redolog.sql
EOS
LN

line_separator
exec_cmd "sudo -u grid -i asmcmd \"rm DATA/dr1db_*.dat\""
LN

line_separator
run_sqlplus "$(drop_primary_cfg)"
LN
