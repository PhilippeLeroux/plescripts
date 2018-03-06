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

	if [ ${#physical_list[@]} -eq 0 ]
	then
		warning "no Physical Standby found."
		LN
		return 0
	fi

	for (( i=0; i<${#physical_list[@]}; ++i ))
	do
		exec_cmd $force_flag "ssh -t -t ${stby_server_list[i]}		\
							\". .bash_profile;						\
							~/plescripts/db/drop_pdb.sh				\
											-db=${physical_list[i]}	\
											-pdb=${pdb}				\
											-nolog					\
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

# $1 pdb name
function drop_db_link_for_refresh_and_update_tnsnames
{
typeset	-r	query=\
"select
	db_link
from
	all_db_links
where
	db_link like '%$(to_upper $(mk_oci_service $1))'
;"
	typeset	-r	db_link_name="$(sqlplus_exec_query "$query" | tail -1)"
	if [ x"$db_link_name" == x ]
	then
		warning "No db link found for pdb $1"
		LN
	else
		info "Drop database link $db_link_name"
		sqlplus_cmd "$(set_sql_cmd "drop database link $db_link_name;")"
		LN
		info "Delete $db_link_name from tnsnames.ora"
		exec_cmd "~/plescripts/db/delete_tns_alias.sh -tnsalias=$db_link_name"
		LN
	fi
}

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_param_invalid role "primary physical"	"$str_usage"

if ! service_exists $db $(mk_oci_service $pdb)
then
	if [ "$role" != "physical" ]
	then	# Le script étant lancé via ssh est un '</dev/null' la réponse ne
			# peut être saisie.
		warning "Service not exists for pdb $pdb."
		confirm_or_exit "Continue"
	fi
fi

[ $log == yes ] && ple_enable_log -params $PARAMS || true

if command_exists olsnodes
then
	typeset	-r	crs_used=yes
else
	typeset	-r	crs_used=no
fi

[ $crs_used == yes ] && exit_if_database_not_exists $db || true

exit_if_ORACLE_SID_not_defined

typeset	-r	dataguard=$(dataguard_config_available)
typeset	-i	count_stby_error=0

info "Dataguard : $dataguard"
LN

typeset -a physical_list
typeset -a stby_server_list
load_stby_database

for stby_name in ${physical_list[*]}
do
	if stby_is_disabled $stby_name
	then
		((++count_stby_error))
		warning "Physical database $stby_name is disabled."
		LN
	fi
done

if [ $count_stby_error -ne 0 ]
then
	confirm_or_exit "Continue"
	LN
fi

wait_if_high_load_average

if [ $dataguard == yes ]
then
	if [ $role == primary ]
	then	# Physical standby must be deleted first
		if [ $count_stby_error -ne 0 ]
		then
			warning "Standby database disabled."
			LN
		else
			exit_if_db_not_primary_database
			close_pdb_on_physical_standby_database
		fi
	else
		exit_if_db_not_physical_standby_database
	fi
elif [ $role == physical ]
then
	error "role = physical and no dataguard ?"
	exit 1
fi

wait_if_high_load_average

if [ $(is_application_seed $pdb) == yes ]
then
	info "Drop a seed."
	sqlplus_cmd "$(set_sql_cmd "@drop_pdbseed $pdb")"
	LN
	exit 0
fi

if [ $crs_used == yes ]
then
	stop_and_remove_dbfs
elif [ -f $HOME/${pdb}_dbfs.cfg ]
then
	exec_cmd "~/plescripts/db/dbfs/drop_dbfs.sh -db=$db -pdb=$pdb -skip_drop_user"
fi

wait_if_high_load_average

if [ $(is_refreshable_pdb $pdb) == no ]
then
	line_separator
	info "Delete credential for sys"
	exec_cmd "~/plescripts/db/wallet/delete_credential.sh -tnsalias=sys${pdb}"
	LN

	wait_if_high_load_average

	if [ $crs_used == yes ]
	then
		exec_cmd "~/plescripts/db/drop_all_services_for_pdb.sh -db=$db -pdb=$pdb"
	else
		exec_cmd "~/plescripts/db/fsdb_drop_all_services_for_pdb.sh -db=$db -pdb=$pdb"
	fi

	wait_if_high_load_average
else
	line_separator
	info "Refreshable PDB no service to delete."
	LN
	drop_db_link_for_refresh_and_update_tnsnames $pdb
fi

if [[ $dataguard == no || $role == primary ]]
then
	function sql_drop_pdb
	{
		set_sql_cmd "alter pluggable database $pdb close immediate instances=all;"
		set_sql_cmd "drop pluggable database $pdb including datafiles;"
	}

	line_separator
	sqlplus_cmd "$(sql_drop_pdb)"
	LN
else # physical standby
	line_separator
	sqlplus_cmd	\
		"$(set_sql_cmd "alter pluggable database $pdb close immediate instances=all;")"
	LN
fi
