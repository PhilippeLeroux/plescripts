#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage="Usage : $ME -db=name"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

ple_enable_log -params $PARAMS

exit_if_param_undef db	"$str_usage"

must_be_user root

typeset -r lower_db=$(to_lower $db)

if test_if_cmd_exists crsctl
then
	typeset crs_used=yes
else
	typeset crs_used=no
fi

if [ $crs_used == yes ]
then
	info "Check DBFS ressource"
	while read res_name
	do
		[ x"$res_name" == x ] && continue || true

		exec_cmd -c "crsctl delete res $res_name -f"
		LN
	done<<<"$(crsctl stat res -t | grep -E ".*\.dbfs$")"
	LN
fi

line_separator
info "Drop wallet."
exec_cmd "su - oracle -c '~/plescripts/db/wallet/delete_all_credentials.sh'"
exec_cmd "su - oracle -c '~/plescripts/db/wallet/drop_wallet.sh'"
LN

line_separator
# Point de montage non supprimé et fstab non mis à jour.
info "Drop DBFS config"
exec_cmd "su - oracle -c 'rm -f *dbfs.cfg'"
LN

if [ $crs_used == yes ]
then
	line_separator
	#	Supprime la base du GI :
	exec_cmd -c "srvctl stop database -db $db -stopoption ABORT -force"
	exec_cmd -c "srvctl remove database -db $lower_db<<<y"
	LN
else
	line_separator
	exec_cmd -c "su - oracle -c \"lsnrctl stop\""
	LN
fi

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

pid_list="$(ps -ef|grep -iE "[o]ra_pmon_${db}"|\
					tr -s [:space:] | cut -d\  -f2 | xargs)"
if [ x"$pid_list" != x ]
then
	line_separator
	exec_cmd "kill -9 $pid_list"
	# on aura un problème avec ASM il faut lui laisser le temps
	# de prendre en compte le kill.
	timing 5 "ASM Temporisation"
	LN
fi

line_separator
oracle_rm_1="su - oracle -c \"rm -rf \\\$ORACLE_BASE/cfgtoollogs/dbca/${db}*\""
oracle_rm_2="su - oracle -c \"rm -rf \\\$ORACLE_BASE/diag/rdbms/$lower_db\""
oracle_rm_3="su - oracle -c \"rm -rf \\\$ORACLE_HOME/dbs/*${db}*\""
oracle_rm_4="su - oracle -c \"rm -rf \\\$ORACLE_BASE/admin/$db\""
oracle_rm_5="su - oracle -c \"rm -rf \\\$TNS_ADMIN/tnsnames.ora\""
oracle_rm_6="su - oracle -c \"rm -rf \\\$TNS_ADMIN/listener.ora\""
oracle_rm_7="su - oracle -c \"rm -rf \\\$TNS_ADMIN/sqlnet.ora\""
oracle_rm_8="su - oracle -c \"rm -rf log\""
oracle_rm_9="su - oracle -c \"rm -rf $db\""

clean_oratab_cmd1="sed  \"/${db:0:8}[_|0-9]\{0,1\}.*/d\" /etc/oratab > /tmp/oratab"
clean_oratab_cmd2="cat /tmp/oratab > /etc/oratab && rm /tmp/oratab"

execute_on_all_nodes "$oracle_rm_1"
LN
execute_on_all_nodes "$oracle_rm_2"
LN
execute_on_all_nodes "$oracle_rm_3"
LN
execute_on_all_nodes "$oracle_rm_4"
LN
execute_on_all_nodes "$oracle_rm_5"
LN
execute_on_all_nodes "$oracle_rm_6"
LN
execute_on_all_nodes "$oracle_rm_7"
LN
execute_on_all_nodes "$oracle_rm_8"
LN
execute_on_all_nodes "$oracle_rm_9"
LN

exec_cmd -c "$clean_oratab_cmd1"
exec_cmd -c "$clean_oratab_cmd2"
LN

execute_on_other_nodes "$clean_oratab_cmd1"
execute_on_other_nodes "$clean_oratab_cmd2"
LN

line_separator
execute_on_all_nodes "su - oracle -c '~/plescripts/db/wallet/drop_wallet.sh'"
LN

if [ $crs_used == yes ]
then
	line_separator
	info "Remove database files from ASM"
	exec_cmd -c "su - grid -c \"asmcmd rm -rf DATA/$db\""
	exec_cmd -c "su - grid -c \"asmcmd rm -rf FRA/$db\""
	rm_error=$?
	LN

	if [ $rm_error -ne 0 ]
	then
		info "RAC 12cR2 execute :"
		info "$ crsctl stop cluster -all"
		info "$ crsctl start cluster -all"
		info "$ $ME"
		LN
	fi
else
	line_separator
	info "Clean up directories"
	exec_cmd rm -rf $ORCL_FS_DATA/$db
	exec_cmd rm -rf $ORCL_FS_FRA/$db
	LN
fi

line_separator
info "${GREEN}done.${NORM}"
