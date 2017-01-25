#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=<str> Nom de la base à supprimer.
	-y        No confirmation.
"

typeset db=undef
typeset	confirm=-confirm

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_upper ${1##*=})
			shift
			;;

		-y)
			confirm=""
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

exit_if_param_undef db	"$str_usage"

function error_msg_on_script_failed
{
	LN
	line_separator
	info "Si le nom de la base $db et le mot de passe sys $oracle_password sont correctes,"
	info "exécuter avec le compte root :"
	LN
	info "$ cd ~/plescripts/db"
	info "$ ./remove_all_files_for_db.sh -db=$db"
	LN
}

line_separator
info "Delete services :"
exec_cmd "~/plescripts/db/drop_all_services.sh -db=$db"
LN

line_separator
info "Delete database :"
LN

trap '[ "$?" -ne 0 ] && error_msg_on_script_failed' EXIT

add_dynamic_cmd_param "-deleteDatabase"
add_dynamic_cmd_param "    -sourcedb       $db"
add_dynamic_cmd_param "    -sysDBAUserName sys"
add_dynamic_cmd_param "    -sysDBAPassword $oracle_password"
add_dynamic_cmd_param "    -silent"
exec_dynamic_cmd $confirm "dbca"
LN

typeset -r rm_1="rm -rf $ORACLE_BASE/cfgtoollogs/dbca/${db}*"
typeset -r rm_2="rm -rf $ORACLE_BASE/diag/rdbms/$(to_lower $db)"
typeset -r rm_3="rm -rf $ORACLE_BASE/admin/$db"
typeset -r rm_4="rm -rf $ORACLE_HOME/dbs/*${db}*"

line_separator
info "Purge des répertoires :"
LN
exec_cmd "$rm_1"
execute_on_other_nodes "$rm_1"
LN
exec_cmd "$rm_2"
execute_on_other_nodes "$rm_2"
LN
exec_cmd "$rm_3"
execute_on_other_nodes "$rm_3"
LN
exec_cmd "$rm_4"
execute_on_other_nodes "$rm_4"
LN

if [ x"$gi_node_list" != x ]
then	#	Sur les RACs les nom des instances ont été ajoutés.
	typeset -r clean_oratab_cmd1="sed  '/${db:0:8}_\{,1\}[0-9].*/d' /etc/oratab > /tmp/oracle_oratab"
	typeset -r clean_oratab_cmd2="cat /tmp/oracle_oratab > /etc/oratab && rm /tmp/oracle_oratab"

	line_separator
	info "Remove instance name from /etc/oratab."
	exec_cmd "$clean_oratab_cmd1"
	exec_cmd "$clean_oratab_cmd2"
	LN

	execute_on_other_nodes "$clean_oratab_cmd1"
	execute_on_other_nodes "$clean_oratab_cmd2"
	LN
fi

if $(test_if_cmd_exists olsnodes)
then
	line_separator
	info "Clean up ASM :"
	exec_cmd -c "sudo -u grid -i asmcmd rm -rf DATA/$db"
	exec_cmd -c "sudo -u grid -i asmcmd rm -rf FRA/$db"
	LN
fi

info "${GREEN}Done.${NORM}"
LN
