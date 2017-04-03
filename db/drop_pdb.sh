#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage :
$ME
	-db=name
	-pdb=name
	[-physical]  Physical Standby
	[-force]     don't stop on error
"

typeset db=undef
typeset pdb=undef
typeset	role=primary
typeset	force_flag

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

		-physical)
			role=physical
			shift
			;;

		-force)
			force_flag="-c"
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

function exit_if_db_not_primary_database
{
	if  ! dgmgrl sys/$oracle_password 'show configuration' |\
											grep -q "$db\s*- Primary database"
	then
		error "No primary database named $db"
		LN
		exec_cmd "dgmgrl -silent sys/$oracle_password 'show configuration'"
		LN
		exit 1
	fi
}

function exit_if_db_not_physical_standby_database
{
	if  ! dgmgrl sys/$oracle_password 'show configuration' |\
								grep -q "$db\s*- Physical standby database"
	then
		error "No physical standby database named $db"
		LN
		exec_cmd "dgmgrl -silent sys/$oracle_password 'show configuration'"
		LN
		exit 1
	fi
}

function drop_pdb_on_physical_standby_database
{
	line_separator
	info "Drop pdb $pdb on physical standby database."
	LN

	typeset -a physical_list
	typeset -a stby_server_list

	#	Load physical standby names.
	typeset name
	while read name
	do
		physical_list+=( $(to_upper $name) )
	done<<<"$(dgmgrl sys/$oracle_password 'show configuration'	|\
					grep "Physical standby" | awk '{ print $1 }')"

	if [ ${#physical_list[@]} -eq 0 ]
	then
		warning "no Physical Standby found."
		LN
		return 0
	fi

	#	Load physical standby servers.
	typeset stby_name
	for stby_name in ${physical_list[*]}
	do
		stby_server_list+=($(tnsping $stby_name | tail -2 | head -1 |\
			sed "s/.*(\s\{0,\}HOST\s\{0,\}=\s\{0,\}\(.*\)\s\{0,\})\s\{0,\}(\s\{0,\}PORT.*/\1/"))
	done

	for i in $( seq 0 $(( ${#physical_list[@]} - 1 )) )
	do
		exec_cmd $force_flag "ssh -t -t ${stby_server_list[i]}				\
							\". .bash_profile;								\
							cd plescripts/db;								\
							./drop_pdb.sh	-db=${physical_list[i]}			\
											-pdb=${pdb}						\
											-physical\"</dev/null"

	done
}

function stop_and_remove_dbfs
{
	typeset -r res="pdb.${pdb}.dbfs"
	if grep -qE "CRS-2613"<<<$(crsctl stat res $res)
	then
		return 0 # le service n'existe pas
	fi

	exec_cmd "~/plescripts/db/dbfs/drop_dbfs.sh -db=$db -pdb=$pdb -skip_drop_user"
}

ple_enable_log

script_banner $ME $*

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_param_invalid role "primary physical"	"$str_usage"

test_if_cmd_exists olsnodes
[ $? -eq 0 ] && crs_used=yes || crs_used=no

[ $crs_used == yes ] && exit_if_database_not_exists $db || true

exit_if_ORACLE_SID_not_defined

typeset	-r dataguard=$(dataguard_config_available)

info "Dataguard : $dataguard"
LN

if [ $dataguard == yes ]
then
	if [ $role == primary ]
	then	# Physical standby must be deleted first
		exit_if_db_not_primary_database
		drop_pdb_on_physical_standby_database
	else
		exit_if_db_not_physical_standby_database
	fi
elif [ $role == physical ]
then
	error "role = physical and no dataguard ?"
	exit 1
fi

if [ $crs_used == yes ]
then
	stop_and_remove_dbfs
elif [ -f $HOME/${pdb}_dbfs.cfg ]
then
	exec_cmd "~/plescripts/db/dbfs/drop_dbfs.sh -db=$db -pdb=$pdb -skip_drop_user"
fi

line_separator
info "Delete credential for sys"
exec_cmd "wallet/delete_credential.sh -tnsalias=sys${pdb}"
LN

exec_cmd "./drop_all_services_for_pdb.sh -db=$db -pdb=$pdb"

line_separator
if [[ $dataguard == no || $role == primary ]]
then
	function sql_drop_pdb
	{
		set_sql_cmd "alter pluggable database $pdb close immediate instances=all;"
		set_sql_cmd "drop pluggable database $pdb including datafiles;"
	}

	sqlplus_cmd "$(sql_drop_pdb)"
else # physical standby
	sqlplus_cmd	\
		"$(set_sql_cmd "alter pluggable database $pdb close immediate;")"
fi
LN
