#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
$ME
	-db=name
	-pdb=name
	[-physical]  Physical Standby : close all PDBs and remove all services & co 
	[-force]     don't stop on error
	[-nolog]
"

typeset db=undef
typeset pdb=undef
typeset	role=primary
typeset	force_flag
typeset log=yes

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

		-nolog)
			log=no
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

function close_pdb_on_physical_standby_database
{
	line_separator
	info "Close pdb $pdb on physical standby database."
	LN

	typeset -a physical_list
	typeset -a stby_server_list

	load_stby_database

	if [ ${#physical_list[@]} -eq 0 ]
	then
		warning "no Physical Standby found."
		LN
		return 0
	fi

	for i in $( seq 0 $(( ${#physical_list[@]} - 1 )) )
	do
		exec_cmd $force_flag "ssh -t -t ${stby_server_list[i]}				\
							\". .bash_profile;								\
							cd plescripts/db;								\
							./drop_pdb.sh	-db=${physical_list[i]}			\
											-pdb=${pdb}						\
											-nolog							\
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

[ $log == yes ] && ple_enable_log -params $PARAMS || true

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

wait_if_high_load_average

if [ $dataguard == yes ]
then
	if [ $role == primary ]
	then	# Physical standby must be deleted first
		exit_if_db_not_primary_database
		close_pdb_on_physical_standby_database
	else
		exit_if_db_not_physical_standby_database
	fi
elif [ $role == physical ]
then
	error "role = physical and no dataguard ?"
	exit 1
fi

wait_if_high_load_average

if [ $crs_used == yes ]
then
	stop_and_remove_dbfs
elif [ -f $HOME/${pdb}_dbfs.cfg ]
then
	exec_cmd "~/plescripts/db/dbfs/drop_dbfs.sh -db=$db -pdb=$pdb -skip_drop_user"
fi

wait_if_high_load_average

line_separator
info "Delete credential for sys"
exec_cmd "wallet/delete_credential.sh -tnsalias=sys${pdb}"
LN

wait_if_high_load_average

if [ $crs_used == yes ]
then
	exec_cmd "./drop_all_services_for_pdb.sh -db=$db -pdb=$pdb"
else
	exec_cmd "./fsdb_drop_all_services_for_pdb.sh -db=$db -pdb=$pdb"
fi

wait_if_high_load_average

line_separator
if [[ $dataguard == no || $role == primary ]]
then
	line_separator
	function sql_drop_pdb
	{
		set_sql_cmd "alter pluggable database $pdb close immediate instances=all;"
		set_sql_cmd "drop pluggable database $pdb including datafiles;"
	}

	sqlplus_cmd "$(sql_drop_pdb)"
	LN
else # physical standby
	sqlplus_cmd	\
		"$(set_sql_cmd "alter pluggable database $pdb close immediate instances=all;")"
	LN
fi
