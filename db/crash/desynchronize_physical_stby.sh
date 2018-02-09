#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC
PAUSE=OFF

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -i loops=2

typeset -r str_usage=\
"Usage :
$ME
	-db=db_name
	-pdb=pdb_name
	[-loops=$loops] nombre d'insertion de la table my_objects dans elle même.
"

typeset db=undef
typeset pdb=undef

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

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-loops=*)
			loops=${1##*=}
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

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

typeset -r ID="$db[$pdb] :"

typeset -r path=~/plescripts/db/crash

typeset -r dbrole=$(read_database_role $db)

if [ "$dbrole" != primary ]
then
	error "$ID role must be primary"
	LN
	exit 1
fi

typeset -a physical_list
typeset -a stby_server_list
load_stby_database
typeset -r dbstby=${physical_list[0]}

info "Stop stby database $dbstby"
sqlplus_cmd_with "sys/$oracle_password@${dbstby} as sysdba"	\
							"$(set_sql_cmd "shutdown immediate;")"
LN
test_pause

info "$ID create table my_object"
sqlplus_cmd_with "sys/$oracle_password@${pdb}_oci as sysdba"	\
							"$(set_sql_cmd "@$path/my_object.sql $loops")"
LN
test_pause

info "$ID switch archivelog"
function sqlcmd_switch_archivelog
{
	set_sql_cmd "alter system switch logfile;"
	set_sql_cmd "alter system switch logfile;"
	set_sql_cmd "alter system switch logfile;"
	set_sql_cmd "alter system switch logfile;"
	set_sql_cmd "alter system switch logfile;"
}
sqlplus_cmd "$(sqlcmd_switch_archivelog)"
LN

typeset -r recovery_path="$(orcl_parameter_value db_recovery_file_dest)"
typeset -r archivelog_path"=$recovery_path/$(to_upper $db)/archivelog"
info "$ID remove all archivelog"
if command_exists crsctl
then
	exec_cmd "sudo -iu grid asmcmd ls $archivelog_path/"
	exec_cmd "sudo -iu grid asmcmd rm -rf $archivelog_path/*"
	# Erreur avec la 12.1
	exec_cmd -c "sudo -iu grid asmcmd ls $archivelog_path/"
	LN
else
	exec_cmd "ls -rtl $archivelog_path/"
	exec_cmd "rm -rf $archivelog_path/*"
	exec_cmd "ls -rtl $archivelog_path/"
	LN

	info "Il faut recréer le répertoire du jour sinon la commande"
	info "alter system archive log current; ne fonctionnera pas."
	exec_cmd -c "mkdir $archivelog_path/$(date +%Y_%m_%d)"
	LN
fi
test_pause

info "Start stby database $dbstby"
sqlplus_cmd_with "sys/$oracle_password@${dbstby} as sysdba"	\
								"$(set_sql_cmd "startup;")"
LN

timing 25
LN

exec_cmd "dgmgrl -silent -echo sys/$oracle_password 'show configuration'"
exec_cmd "dgmgrl -silent -echo sys/$oracle_password 'show database $dbstby'"
LN
