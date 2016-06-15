#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=<str> Nom de la base à supprimer.
"

typeset db=undef

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

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef db	"$str_usage"

typeset -r upper_db=$(to_upper $db)

line_separator
info "Suppression de la base :"
LN

exec_cmd "dbca -deleteDatabase -sourcedb $db -sysDBAUserName sys -sysDBAPassword $oracle_password -silent"
LN

#	Les 2 fonctions sont dupliquées de database_servers/uninstall_all.sh
function get_other_nodes
{
	if $(test_if_cmd_exists olsnodes)
	then
		typeset nl=$(olsnodes | xargs)
		if [ x"$nl" != x ]
		then # olsnodes ne retourne rien sur un SINGLE
			sed "s/$(hostname -s) //" <<<"$nl"
		fi
	fi
}

function execute_on_other_nodes
{
	typeset -r cmd="$@"

	for node in $node_list
	do
		exec_cmd "ssh $node $cmd"
	done
}

typeset -r node_list=$(get_other_nodes)

typeset -r rm_1="rm -rf $ORACLE_BASE/cfgtoollogs/dbca/$upper_db"
typeset -r rm_2="rm -rf $ORACLE_BASE/diag/rdbms/$db"

line_separator
info "Purge des répertoires :"
LN

exec_cmd "$rm_1"
execute_on_other_nodes "$rm_1"
LN

exec_cmd "$rm_2"
execute_on_other_nodes "$rm_2"
LN

if $(test_if_cmd_exists olsnodes)
then
	line_separator
	info "Purge de ASM :"
	exec_cmd -c "sudo -u grid -i asmcmd rm -rf DATA/$upper_db"
	exec_cmd -c "sudo -u grid -i asmcmd rm -rf FRA/$upper_db"
	LN
fi
