#!/bin/sh

#	ts=4	sw=4

PLELIB_OUTPUT=FILE
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
			first_args=-emul
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

[ "$USER" != "root" ] && error "Only root can execute this script" && exit 1

typeset -r upper_db=$(to_upper $db)

ORACLE_BASE=/u01/app/oracle

exec_cmd -c "srvctl stop database -db $db"
exec_cmd -c "srvctl remove database -db $db<<<y"

oracle_rm_1="su - oracle -c \"rm -rf $ORACLE_BASE/cfgtoollogs/dbca/$upper_db\""
oracle_rm_2="su - oracle -c \"rm -rf $ORACLE_BASE/diag/rdbms/$db\""

line_separator
info "Supprime tous les fichiers d'oracle sur le noeud $(hostname -s)"
exec_cmd -c "$oracle_rm_1"
exec_cmd -c "$oracle_rm_2"
LN

typeset -r cfg_path=~/plescripts/infra/${db}
if [ -d $cfg_path ]
then
	oracle_rm_1=$(escape_2xquotes $oracle_rm_1)
	oracle_rm_2=$(escape_2xquotes $oracle_rm_2)
	for node_file in $cfg_path/node*
	do
		node_name=$(cat $node_file | cut -d':' -f2)
		if [ $node_name != $(hostname -s) ]
		then
			line_separator
			info "Supprime les fichiers oracle sur le noeud $node_name"
			exec_cmd -c "ssh $node_name $oracle_rm_1"
			exec_cmd -c "ssh $node_name $oracle_rm_2"
			LN
		fi
	done
fi

line_separator
info "Supprime les datafiles de ASM"
exec_cmd -c "su - grid -c \"asmcmd rm -rf DATA/$upper_db\""
exec_cmd -c "su - grid -c \"asmcmd rm -rf FRA/$upper_db\""
