#!/bin/bash

# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=name"

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
			typeset -r db=$(to_upper ${1##*=})
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

typeset -r lower_db=$(to_lower $db)

line_separator
#	Supprime la base du GI :
exec_cmd -c "srvctl stop database -db $db -stopoption ABORT -force"
exec_cmd -c "srvctl remove database -db $lower_db<<<y"
LN

line_separator
#	Si la base n'était pas dans le GI alors la base est toujours démarrée.

#	Si la base est minimaliste et en nomount alors le kill des process ne suffit
#	pas, il faut faire un shutdown abort.
cat <<EOS >/tmp/stop_orcl.sh
export ORACLE_SID=$db
\sqlplus -s sys/$oracle_password as sysdba<<XXX
shutdown abort
exit
XXX
EOS
chown oracle:oinstall /tmp/stop_orcl.sh
chmod u+x /tmp/stop_orcl.sh
exec_cmd -c "su - oracle -c /tmp/stop_orcl.sh"
LN

line_separator
exec_cmd -c "kill -9 $(ps -ef| grep -E \"[${db:0:1}]${db:1}\" | tr -s [:space:] | cut -d\  -f2 | xargs)"
if [ $? -eq 0 ]
then	# Si le kill est effectif on aura un problème avec ASM il faut lui laisser
		# le temps de prendre en compte le kill.
	timing 5 "ASM Temporisation"
fi

line_separator
oracle_rm_1="su - oracle -c 'rm -rf \$ORACLE_BASE/cfgtoollogs/dbca/${db}*'"
oracle_rm_2="su - oracle -c 'rm -rf \$ORACLE_BASE/diag/rdbms/$lower_db'"
oracle_rm_3="su - oracle -c 'rm -rf \$ORACLE_HOME/dbs/*${db}*'"
oracle_rm_4="su - oracle -c 'rm -rf \$ORACLE_BASE/admin/$db'"

clean_oratab_cmd1="sed  '/$db[_|0-9].*/d' /etc/oratab > /tmp/oratab"
clean_oratab_cmd2="cat /tmp/oratab > /etc/oratab && rm /tmp/oratab"

info "Remove all Oracle files on node $(hostname -s)"
exec_cmd -c "$oracle_rm_1"
exec_cmd -c "$oracle_rm_2"
exec_cmd -c "$oracle_rm_3"
exec_cmd -c "$oracle_rm_4"
LN

exec_cmd -c "$clean_oratab_cmd1"
exec_cmd -c "$clean_oratab_cmd2"
LN

typeset -r cfg_path=~/plescripts/database_servers/${db}
if [ -d $cfg_path ]
then
	oracle_rm_1=$(escape_2xquotes $oracle_rm_1)
	oracle_rm_2=$(escape_2xquotes $oracle_rm_2)
	oracle_rm_3=$(escape_2xquotes $oracle_rm_3)
	oracle_rm_4=$(escape_2xquotes $oracle_rm_3)
	for node_file in $cfg_path/node*
	do
		node_name=$(cat $node_file | cut -d: -f2)
		if [ $node_name != $(hostname -s) ]
		then
			warning "RAC : ATTENTION PAS TESTE DEPUIS CHANGEMENT DES VARIABLES oracle_rm_X"
			line_separator
			info "Remove all Oracle's files on node $node_name"
			exec_cmd -c "ssh $node_name '$oracle_rm_1'"
			exec_cmd -c "ssh $node_name '$oracle_rm_2'"
			exec_cmd -c "ssh $node_name '$oracle_rm_3'"
			exec_cmd -c "ssh $node_name '$oracle_rm_4'"
			LN

			exec_cmd -c "ssh $node_name \"$clean_oratab_cmd1\""
			exec_cmd -c "ssh $node_name \"$clean_oratab_cmd1\""
			LN
		fi
	done
fi

line_separator
info "Remove database files from ASM"
exec_cmd -c "su - grid -c \"asmcmd rm -rf DATA/$db\""
exec_cmd -c "su - grid -c \"asmcmd rm -rf FRA/$db\""
LN

line_separator
info "${GREEN}done.${NORM}"
