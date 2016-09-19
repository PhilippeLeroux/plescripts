#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=name -pdbName=name"

info "Running : $ME $*"

typeset db=undef
typeset pdbName=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=$(to_upper ${1##*=})
			shift
			;;

		-pdbName=*)
			pdbName=${1##*=}
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

exit_if_param_undef db		"$str_usage"
exit_if_param_undef pdbName	"$str_usage"

function drop_primary_cfg
{
	to_exec "alter system reset standby_file_management scope=spfile sid='*';"

	to_exec "alter system reset log_archive_config scope=spfile sid='*';"

	to_exec "alter system reset fal_server scope=spfile sid='*';"

	to_exec "alter system reset log_archive_dest_1 scope=spfile sid='*';"

	to_exec "alter system reset log_archive_dest_2 scope=spfile sid='*';"

	to_exec "alter system reset remote_login_passwordfile scope=spfile sid='*';"

	# Les 2 paramètres ne sont pas positionné, mais me sert de mémo pour ailleurs.
	to_exec "alter system reset db_file_name_convert scope=spfile sid='*';"

	to_exec "alter system reset log_file_name_convert scope=spfile sid='*';"
	#	--

	to_exec "alter system reset dg_broker_config_file1 scope=spfile sid='*';"

	to_exec "alter system reset dg_broker_config_file2 scope=spfile sid='*';"

	to_exec "alter system set dg_broker_start=false scope=both sid='*';"

	to_exec "alter database no force logging;"

	to_exec "shutdown immediate"
	to_exec "startup"
}

info "Load env for $db"
ORACLE_SID=$db
ORAENV_ASK=NO . oraenv
LN

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
exec_cmd -c sudo -u grid -i "asmcmd rm -f DATA/$db/dr1db_*.dat"
LN

line_separator
exec_cmd -c ~/plescripts/db/drop_all_services.sh -db=$db
LN

line_separator
exec_cmd -c "~/plescripts/db/create_service_for_standalone_dataguard.sh -db=$db \
		-pdbName=$pdbName -prefixService=pdb${pdbName}"
LN

line_separator
sqlplus_cmd "$(drop_primary_cfg)"
LN
