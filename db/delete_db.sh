#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

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

info "Suppression de la base :"
exec_cmd "dbca -deleteDatabase -sourcedb $db -sysDBAUserName sys -sysDBAPassword $oracle_password -silent"
LN

warning "TODO : Le RAC n'est pas pris en compte, seul le noeud courant est purgé !"
info "Purge du répertoire :"
exec_cmd "rm -rf $ORACLE_BASE/cfgtoollogs/dbca/$upper_db"
exec_cmd "rm -rf $ORACLE_BASE/diag/rdbms/$db"
LN

info "Purge de ASM :"
exec_cmd -c "sudo -u grid -i asmcmd rm -rf DATA/$upper_db"
exec_cmd -c "sudo -u grid -i asmcmd rm -rf FRA/$upper_db"
LN
