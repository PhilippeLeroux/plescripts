#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

typeset db=undef
typeset pdb=undef
typeset admin_user=syspdb
typeset admin_pass=$oracle_password

typeset -r str_usage=\
"Usage :
$ME
	-db=name
	-pdb=name
	[-admin_user=$admin_user]
	[-admin_pass=$admin_pass]
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-pdb=*)
			pdb=$(to_lower ${1##*=})
			shift
			;;

		-admin_user=*)
			admin_user=${1##*=}
			shift
			;;

		-admin_pass=*)
			admin_pass=${1##*=}
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

must_be_user oracle

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_ORACLE_SID_not_defined

typeset	-r dataguard=$(dataguard_config_available)

if [[ $dataguard == yes && $gi_count_nodes -gt 1 ]]
then
	error "RAC + Dataguard not supported."
	exit 1
fi

if [ $dataguard == yes ]
then
	typeset -r primary="$(read_primary_name)"
	if [ "$primary" != "$db" ]
	then
		error "db=$db, primary name is $primary"
		error "Execute script on primary database."
		LN
		exit 1
	fi

	typeset -a physical_list
	typeset -a stby_server_list
	load_stby_database
fi

info "On database $db create pdb $pdb"
if [ $dataguard == yes ]
then
	info "Physical standby : ${physical_list[*]}"
	info "Servers          : ${stby_server_list[*]}"
fi
LN

line_separator
function ddl_create_pdb
{
	set_sql_cmd "whenever sqlerror exit 1;"
	set_sql_cmd "create pluggable database $pdb admin user $admin_user identified by $admin_pass;"
}
sqlplus_cmd "$(ddl_create_pdb)"
LN

for stby in ${physical_list[*]}
do
	exec_cmd "dgmgrl -silent sys/Oracle12 'show database ${stby}'"
	LN
done

line_separator
info "Create services"
if [ $dataguard == yes ]
then
	for i in $( seq 0 $(( ${#physical_list[@]} - 1 )) )
	do
		add_dynamic_cmd_param "-db=$primary"
		add_dynamic_cmd_param "-pdb=$pdb"
		add_dynamic_cmd_param "-standby=${physical_list[i]}"
		add_dynamic_cmd_param "-standby_host=${stby_server_list[i]}"
		exec_dynamic_cmd "./create_srv_for_dataguard.sh"
		LN
	done
else
	if [ $gi_count_nodes -eq 1 ]
	then
		exec_cmd ./create_srv_for_single_db.sh -db=$db -pdb=$pdb
	else
		typeset poolName="$(srvctl config database -db daisy	|\
								grep "^Server pools:" | awk '{ print $3 }')"
		exec_cmd ./create_srv_for_rac_db.sh	\
								-db=$db -pdb=$pdb -poolName=$poolName
	fi
fi

if [ $dataguard == yes ]
then
	function add_temp_tbs_to
	{
		set_sql_cmd "alter session set container=$1;"
		set_sql_cmd "alter tablespace temp add tempfile;"
	}

	line_separator
	info "12cR1 : temporary tablespace not created."
	for stby_name in ${physical_list[*]}
	do
		sqlplus_cmd_with sys/$oracle_password@$stby_name as sysdba	\
												"$(add_temp_tbs_to $pdb)"
		LN
	done
fi
