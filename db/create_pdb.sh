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
typeset admin_user=ple
typeset admin_pass=ple

typeset -r str_usage=\
"Usage :
$ME
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

# print to stdout primary database name
function read_primary_name
{
	dgmgrl sys/$oracle_password 'show configuration'	|\
				grep "Primary database" | awk '{ print $1 }'
}

# buil arrays physical_list & stby_server_list
function load_stby_database
{
	typeset name
	while read name
	do
		physical_list+=( $name )
	done<<<"$(dgmgrl sys/$oracle_password 'show configuration'	|\
					grep "Physical standby" | awk '{ print $1 }')"

	typeset stby_name
	for stby_name in ${physical_list[*]}
	do
		stby_server_list+=($(tnsping $stby_name | tail -2 | head -1 |\
					sed "s/.*(\s\?HOST\s\?=\s\?\(.*\)\s\?)\s\?(\s\?PORT.*/\1/"))
	done

}

function add_temp_tbs_to
{
	set_sql_cmd "alter session set container=$1;"
	set_sql_cmd "alter tablespace temp add tempfile;"
}

if dataguard_config_available
then
	typeset	-r dataguard=yes
else
	typeset	-r dataguard=no
fi

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

info "On database $primary create pdb $pdb"
if [ $dataguard == yes ]
then
	info "Physical standby : ${physical_list[*]}"
	info "Servers          : ${stby_server_list[*]}"
fi
LN

line_separator
sqlplus_cmd "$(set_sql_cmd "create pluggable database $pdb admin user $admin_user identified by $admin_pass;")"
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
		warning "TODO : RAC create services with create_srv_for_rac_db.sh"
	fi
fi

if [ $dataguard == yes ]
then
	line_separator
	info "12cR1 : temporary tablespace not created."
	for stby_name in ${physical_list[*]}
	do
		sqlplus_cmd_with sys/$oracle_password@$stby_name as sysdba	\
												"$(add_temp_tbs_to $pdb)"
		LN
	done
fi
