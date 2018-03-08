#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	orcl_release="$(read_orcl_release)"

typeset		db=undef
typeset		pdb=undef
typeset		from_pdb=default
typeset		no_data=no
typeset		wallet=${WALLET:-$(enable_wallet $orcl_release)}
typeset		sampleSchema=no
typeset		as_seed=no
typeset		ro=no
typeset		admin_user=pdbadmin
typeset		admin_pass=$oracle_password

typeset		log=yes

add_usage "-db=name"			"Database name."
add_usage "-pdb=name"			"PDB name."
add_usage "[-sampleSchema=$sampleSchema]"	"yes|no"
add_usage "[-as_seed]"			"Create a seed pdb 12cR2."
add_usage "[-ro]"				"Fake a seed pdb 12cR1."
add_usage "[-from_pdb=name]"	"Clone from pdb 'name'"
add_usage "[-no_data]"			"Clone without data."
add_usage "[-wallet=$wallet]"	"yes|no yes : Use Wallet Manager for pdb connection."
add_usage "[-admin_user=$admin_user]"
add_usage "[-admin_pass=$admin_pass]"
add_usage "[-nolog]"

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)

Variable WALLET override the default value, ex export WALLET=no
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

		-sampleSchema=*)
			sampleSchema=$(to_lower ${1##*=})
			shift
			;;

		-from_pdb=*)
			from_pdb=$(to_lower ${1##*=})
			shift
			;;

		-no_data)
			no_data=yes
			shift
			;;

		-ro)
			ro=yes
			shift
			;;

		-as_seed)
			as_seed=yes
			shift
			;;

		-wallet=*)
			wallet=$(to_lower ${1##*=})
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

must_be_user oracle

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_param_invalid	wallet			"yes no"	"$str_usage"
exit_if_param_invalid	sampleSchema	"yes no"	"$str_usage"

[ $log == yes ] && script_start || true

if command_exists olsnodes
then
	typeset -r crs_used=yes
else
	typeset -r crs_used=no
fi

exit_if_database_not_exists $db

exit_if_ORACLE_SID_not_defined

[ $log == yes ] && ple_enable_log -params $PARAMS || true

function print_pdbs_status
{
	info "Primary $db status :"
	sqlplus_cmd "$(set_sql_cmd @lspdbs)"
	LN

	if [[ $dataguard == yes && $adg == yes ]]
	then
		if [ $count_stby_error -ne 0 ]
		then
			warning "At least one Physical Database is disabled."
			LN
		else
			for stby_name in ${physical_list[*]}
			do
				info "Standby $stby_name status :"
				typeset conn_string="sys/$oracle_password@$stby_name as sysdba"
				sqlplus_cmd_with $conn_string "$(set_sql_cmd @lspdbs)"
				LN
			done
		fi
	fi
}

# $1 seed name
# At the end pdb is open RW.
function create_pdb_as_application
{
	set_sql_cmd "create pluggable database $1 as application container admin user $admin_user identified by $admin_pass;"
	set_sql_cmd "alter session set container=$1;"
	set_sql_cmd "alter pluggable database open instances=all;"
}

# $1 seed name
# At the end pdb is open RW.
function sql_create_seed_pdb
{
	set_sql_cmd "alter session set container=$1;"
	set_sql_cmd "create pluggable database as seed from $1;"
	set_sql_cmd "alter pluggable database $1\$seed open;"
}

# $1 seed name
# At the end pdb is close.
function sql_run_pdb_to_apppdb
{
	set_sql_cmd "alter session set container=$1\$seed;"
	set_sql_cmd "@?/rdbms/admin/pdb_to_apppdb.sql"
	set_sql_cmd "alter pluggable database application all sync;"
	set_sql_cmd "alter pluggable database close immediate instances=all;"
}

# $1 full pdb name : foo or foo\$seed
# Action on $1 and $1\$seed
function sql_open_seed_ro_and_save_state
{
	set_sql_cmd "alter session set container=$1;"
	set_sql_cmd "alter pluggable database close immediate instances=all;"
	set_sql_cmd "alter pluggable database open read only instances=all;"
	set_sql_cmd "alter pluggable database save state;"
}

function print_warning_seed_and_dg
{
	warning "*********************************************************"
	warning "Dataguard bug :"
	warning "Créer un PDB seed ou cloner depuis un PDB seed perso va"
	warning "désynchroniser la standby. Il faudra recréer la standby !"
	warning "*********************************************************"
	LN
	confirm_or_exit "Continuer"
}

function clone_pdb_as_seed
{
	[ $dataguard == yes ] && print_warning_seed_and_dg || true

	line_separator
	info "Create PDB $pdb as application container."
	sqlplus_cmd "$(create_pdb_as_application $pdb)"
	LN

	line_separator
	info "Create seed $pdb\$seed RW"
	sqlplus_cmd "$(sql_create_seed_pdb $pdb)"
	LN

	line_separator
	info "Run pdb_to_apppdb.sql on $pdb"
	sqlplus_cmd "$(sql_run_pdb_to_apppdb $pdb)"
	LN

	line_separator
	info "Open seed $pdb RO and save state."
	sqlplus_cmd "$(sql_open_seed_ro_and_save_state $pdb)"
	LN

	line_separator
	info "Open seed $pdb\$seed RO and save state."
	sqlplus_cmd "$(sql_open_seed_ro_and_save_state $pdb\$seed)"
	LN
}

function clone_pdb_from_seed
{
	function ddl_create_pdb
	{
		set_sql_cmd "whenever sqlerror exit 1;"
		set_sql_cmd "create pluggable database $pdb admin user $admin_user identified by $admin_pass standbys=all;"
	}
	sqlplus_cmd "$(ddl_create_pdb)"
	[ $? -ne 0 ] && exit 1 || true
}

# $1 pdb name
function clone_from_pdb
{
	typeset	-r	from_pdb=$1
	line_separator
	info "Clone $pdb from $from_pdb"
	if [ $from_pdb_is_a_seed == yes ]
	then
		info "    cloning from a seed."
		LN
	fi

	if [[ $dataguard == yes && $from_pdb_is_a_seed == no ]]
	then
		warning "Dataguard bug : $from_pdb must be reopen RO"
		LN
	fi

	# $1 pdb name
	function ddl_clone_from_pdb
	{
		set_sql_cmd "whenever sqlerror exit 1;"
		if [[ $dataguard == yes && $from_pdb_is_a_seed == no ]]
		then
			# Sur un Dataguard si le PDB est RW alors la synchro est HS
			# Il faut que le PDB soit RO pour être clonable : BUG or not BUG ??
			# Testé sur la 12.2 c'est la même chose.
			set_sql_cmd "alter pluggable database $1 close immediate instances=all;"
			set_sql_cmd "alter pluggable database $1 open read only instances=all;"
		fi
		if [ $no_data == yes ]
		then
			set_sql_cmd "create pluggable database $pdb from $1 no data standbys=all;"
		else
			set_sql_cmd "create pluggable database $pdb from $1 standbys=all;"
		fi
		if [[ $dataguard == yes && $from_pdb_is_a_seed == no ]]
		then
			set_sql_cmd "alter pluggable database $1 close immediate instances=all;"
			set_sql_cmd "alter pluggable database $1 open read only instances=all;"
		fi
	}

	sqlplus_cmd "$(ddl_clone_from_pdb $from_pdb)"
	[ $? -ne 0 ] && exit 1 || true
}

# $1 pdb name
# Attention pour pouvoir ouvrir en RO un pdb, il doit d'abord avoir été ouvert
# en RW.
function sql_pdb_open_ro_and_save_state
{
	typeset pdb_name=$1
	#	Sur un dataguard le PDB doit être ouvert pour être clonable.
	#	Il sera donc un RO comme PDB$SEED.
	set_sql_cmd "whenever sqlerror exit 1;"

	set_sql_prompt "Open pdb $pdb_name RO"
	set_sql_cmd "alter pluggable database $pdb_name open read only instances=all;"
	set_sql_cmd "alter pluggable database $pdb_name save state;"
}

function create_database_trigger_open_stby_pdb
{
	line_separator
	info "Create trigger open_stby_pdbs_ro (open pdbs RO on standby)"
	sqlplus_cmd "$(set_sql_cmd "@$HOME/plescripts/db/sql/create_trigger_open_stby_pdbs_ro.sql")"
	LN
}

#	Même quand le grid infra est installé il faut utiliser le trigger,
#	sur un close immediate suivie d'un open le Grid ne démarre pas les services.
function create_database_trigger_start_pdb_services
{
	line_separator
	typeset pdbconn="sys/$oracle_password@$(hostname -s):1521/$pdb as sysdba"
	info "Create trigger start_pdb_services"
	sqlplus_cmd_with "$pdbconn"	\
		"$(set_sql_cmd "@$HOME/plescripts/db/sql/create_trigger_start_pdb_services.sql")"
	LN
}

# Print to stdout OFF or ON
function real_time_apply_is
{
	dgmgrl -silent -echo sys/$oracle_password<<<"show database ${physical_list[0]}"|grep -E "Real Time Query:"|awk '{ print $4 }'
}

# TODO : utiliser 'service_name_convert' de 'create pluggable ....' ??  et avec
# le CRS sa donne quoi ??
function create_pdb_services
{
	if [[ $crs_used == no ]]
	then
		create_database_trigger_open_stby_pdb
		create_database_trigger_start_pdb_services
	fi

	if [ $wallet == no ]
	then
		line_separator
		info "Wallet not used."
		LN
		info "Add alias sys$pdb for sysdba connection."
		exec_cmd "$HOME/plescripts/db/add_tns_alias.sh	\
						-service=$pdb					\
						-host_name=$(hostname -s)		\
						-tnsalias=sys$pdb"
		LN

		if [[ $dataguard == yes && ${#physical_list[@]} -ne 0 ]]
		then
			if [ $count_stby_error -ne 0 ]
			then
				warning "Standby database error, tns alias not updated."
				LN
			else
				for stby_server in ${stby_server_list[*]}
				do
					info "Physical server $stby_server"
					exec_cmd "ssh -t oracle@$stby_server					\
									\". .bash_profile	&&					\
									$HOME/plescripts/db/add_tns_alias.sh	\
											-service=$pdb					\
											-host_name=$stby_server			\
											-tnsalias=sys$pdb\""
				done
			fi
		fi
	fi

	line_separator
	info "Create services"
	if [[ $dataguard == yes && ${#physical_list[@]} -ne 0 ]]
	then
		if [ $count_stby_error -ne 0 ]
		then
			warning "Cannot create standby services !"
			LN
			exec_cmd ./create_srv_for_single_db.sh -db=$db -pdb=$pdb
		else
			for (( i=0; i < ${#physical_list[@]}; ++i ))
			do
				add_dynamic_cmd_param "-db=$primary"
				add_dynamic_cmd_param "-pdb=$pdb"
				add_dynamic_cmd_param "-standby=${physical_list[i]}"
				add_dynamic_cmd_param "-standby_host=${stby_server_list[i]}"
				[ $adg == no ] && add_dynamic_cmd_param "-no_adg" || true
				exec_dynamic_cmd "./create_srv_for_dataguard.sh"
				LN
			done
		fi
	else
		if [ $dataguard == yes ]
		then
			warning "Dataguard configured but no physical standby"
			LN
		fi

		if [ $gi_count_nodes -eq 1 ]
		then
			exec_cmd ./create_srv_for_single_db.sh -db=$db -pdb=$pdb
		elif is_rac_one_node $db
		then
			exec_cmd ./create_srv_for_rac_one_node_db.sh -db=$db -pdb=$pdb
		else
			typeset poolName="$(srvctl config database -db $db	|\
								grep "^Server pools:" | awk '{ print $3 }')"
			exec_cmd ./create_srv_for_rac_db.sh	\
									-db=$db -pdb=$pdb -poolName=$poolName
		fi
	fi
}

# Si un PDB est clonée depuis un PDB existant, il faut supprimer tous les
# services du pdb existant qui sont dans le PDB cloné.
function sqlcmd_remove_services_from_cloned_pdb
{
	set_sql_cmd "alter pluggable database $pdb close immediate instances=all;"
	set_sql_cmd "alter pluggable database $pdb open read write instances=all;"
	set_sql_cmd "alter session set container=$pdb;"
	echo "set serveroutput on"
	echo "begin"
	echo "    for s in ( select name from all_services where name != '$(to_lower $pdb)' )"
	echo "    loop"
	echo "        dbms_output.put_line( 'Remove service : '||s.name );"
	echo "        dbms_service.delete_service( s.name );"
	echo "    end loop;"
	echo "end;"
	echo "/"
}

function create_wallet
{
	line_separator
	exec_cmd "~/plescripts/db/add_sysdba_credential_for_pdb.sh -db=$db -pdb=$pdb"
	if [ $dataguard == yes ]
	then
		if [ $count_stby_error -ne 0 ]
		then
			warning "Cannot create sysdba credential on standby databases..."
			LN
		else
			for (( i=0; i < ${#physical_list[@]}; ++i ))
			do
				exec_cmd "ssh ${stby_server_list[i]}	\
					'. .bash_profile;	\
					~/plescripts/db/add_sysdba_credential_for_pdb.sh	\
										-db=${physical_list[i]} -pdb=$pdb'"
				LN
			done
		fi
	fi

	if [[ $orcl_release == 12.2 && $gi_count_nodes -eq 1 ]] && command_exists crsctl
	then
		warning "Database cannot start with wallet enable."
		LN
	fi
}

# $1 pdb name
function open_pdb_and_save_state
{
	typeset pdb_name=$1
	set_sql_cmd "alter pluggable database $pdb_name open instances=all;"
	set_sql_cmd "alter pluggable database $pdb_name save state;"
}

function stby_create_temporary_file
{
	function add_temp_tbs_to
	{
		typeset _pdb=$1
		set_sql_cmd "alter pluggable database $_pdb open read only instances=all;"
		set_sql_cmd "whenever sqlerror exit 1;"
		set_sql_cmd "alter session set container=$_pdb;"
		set_sql_cmd "alter tablespace temp add tempfile;"
	}

	wait_if_high_load_average

	line_separator
	info "12c : temporary tablespace not created on standby."
	if [ $adg == no ]
	then
		warning "  Real Time Apply is OFF"
		warning "  Temporary file cannot be created for standby $pdb."
		LN
		warning "  Create temp file after swichtover or failover manually."
		LN
		return 0
	fi
	# - Parfois la syncho Dataguard n'est pas terminée et dans ce cas l'ouverture
	#   du PDB échoura.
	# - Parfois le PDB n'est pas visible sur la standby, il un stop & go pour
	#   que le PDB devienne visible : bug ?
	timing 20 "Waiting sync"
	for stby_name in ${physical_list[*]}
	do
		typeset conn_string="sys/$oracle_password@$stby_name as sysdba"
		sqlplus_cmd_with $conn_string "$(add_temp_tbs_to $pdb)"
		ret=$?
		LN
		if [ $ret -ne 0 ]
		then
			error "Standby error : slow synchronization ?"
			LN
			exit 1
		fi
	done
}

[[ $ro == yes || $as_seed == yes ]] && wallet=no || true

if [[ $as_seed == yes && $(read_orcl_release) == 12.1 ]]
then
	error "Oracle 12.1 : flag -as_seed not valid, used -ro instead (to fake a seed)."
	LN
	exit 1
fi

typeset	-r	dataguard=$(dataguard_config_available)
typeset	-i	count_stby_error=0

if [ $dataguard == yes ]
then
	if [[ $gi_count_nodes -gt 1 ]]
	then
		error "RAC + Dataguard not supported."
		exit 1
	fi

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
fi

info "On database $db create pdb $pdb"
if [ $dataguard == yes ]
then
	info "Physical standby : ${physical_list[*]}"
	info "Servers          : ${stby_server_list[*]}"
	if [ $(real_time_apply_is) == OFF ]
	then
		typeset	-r	adg=no
		info "Passive Data Guard."
		LN
	else
		typeset	-r	adg=yes
		info "Active Data Guard."
		LN
	fi
elif [ $crs_used == no ]
then # Sans ASM il est nécessaire d'ouvrir la base en RW.
	typeset	-r	adg=yes
fi
LN

wait_if_high_load_average

if [ $from_pdb == default ]
then
	if [ $no_data == yes ]
	then
		warning "flag -no_data ignored."
		LN
	fi
	typeset	-r	from_pdb_is_a_seed=no
	[ $as_seed == yes ] && clone_pdb_as_seed || clone_pdb_from_seed
else
	if [ $as_seed == yes ]
	then
		error "not implemented."
		LN
		exit 1
	fi
	# Oracle BUG :
	#	Si le PDB est cloné depuis un PDB 'application' alors les scripts lssrv.sql
	#	n'affichera pas les noms des services.
	#	Les services existent mais ne sont pas visible depuis la vue cdb_services,
	#	il faut se connecter sur le PDB et utilser la vue all_services.
	typeset	-r	from_pdb_is_a_seed=$(is_application_seed $from_pdb)
	[ $from_pdb_is_a_seed == yes ] && print_warning_seed_and_dg || true
	clone_from_pdb $from_pdb
	# Le pdb $from_pdb s'il est seed mettra en peu de temps à passer en RO.
	# Sur la standby il restera 'mounted' mais ce n'est pas grave, sur un
	# switch il passera RO.
fi
LN

wait_if_high_load_average

for stby in ${physical_list[*]}
do
	exec_cmd "dgmgrl -silent sys/$oracle_password 'show database ${stby}'"
	LN
done

if [[ $from_pdb != default && $from_pdb_is_a_seed == no ]]
then
	info "Remove services cloned from $from_pdb on $db[$pdb]"
	sqlplus_cmd "$(sqlcmd_remove_services_from_cloned_pdb)"
	LN
fi

wait_if_high_load_average

if [[ $adg == yes && $ro == no && $as_seed == no ]] # ou sans dataguard.
then
	info "Open RW $db[$pdb] and save state."
	# Pour ouvrir un PDB RO il faut d'abord l'ouvrir en RW, sinon l'ouverture échoue.
	# si $ro == yes l'ouverture de la base en RO ne posera pas de problème.
	sqlplus_cmd "$(open_pdb_and_save_state $pdb)"
	LN
elif [[ $ro == yes ]]
then
	#	La base est ouverte RW pour 2 raisons :
	#	- Elle ne peut pas être ouvert RO directement après sa création, l'ouvrir
	#	  permet de finir son intégration dans le CDB.
	#	- Pour pouvoir ouvrir le PDB sur la standby il faut qu'elle soit ouverte RW
	#	  sur la primaire.
	line_separator
	info "Open $db[$pdb] RW temporary."
	sqlplus_cmd "$(set_sql_cmd "alter pluggable database $pdb open instances=all;")"
	LN
fi

if [[ $dataguard == yes && $count_stby_error -eq 0 && ${#physical_list[*]} -ne 0 ]]
then
	[ $as_seed == no ] && stby_create_temporary_file || true
fi

if [[ $from_pdb != default && $from_pdb_is_a_seed == yes ]]
then
	function sql_run_approot_to_pdb
	{
		set_sql_cmd "alter session set container=$pdb;"
		set_sql_cmd "@?/rdbms/admin/approot_to_pdb.sql"
	}
	line_separator
	info "Run approot_to_pdb.sql on $db[$pdb]."
	sqlplus_cmd "$(sql_run_approot_to_pdb)"
	LN
fi

if [[ $ro == yes ]]
then
	line_separator
	info "Close $db[$pdb]"
	sqlplus_cmd "$(set_sql_cmd "alter pluggable database $pdb close immediate instances=all;")"
	LN

	# 12.1 & 12.2
	# BUG :	Lors d'un switchover le PDB sera ouvert RW malgrès le 'save state'.
	#		Si la base est redémarré la PDB sera 'mounted' ave le Grid Infra, et
	#		sera RW sans le Grid Infra.
	#		Si on refait un switchover, le PDB est ouvert RO.
	info "Open read only : $db[$pdb]"
	sqlplus_cmd "$(sql_pdb_open_ro_and_save_state $pdb)"
	LN
fi

print_pdbs_status

wait_if_high_load_average

[[ $ro == no && $as_seed == no ]] && create_pdb_services || true

[ $wallet == yes ] && create_wallet || true

if [ $sampleSchema == yes ]
then
	info "Create sample schemas on $db[$pdb]"
	exec_cmd ~/plescripts/db/create_sample_schemas.sh -db=$db -pdb=$pdb
	LN
fi

line_separator
typeset -r violations=\
"select
	name		\"PDB Name\"
,	count(*)	\"PDB Violations\"
from
	pdb_plug_in_violations
where
	status	!= 'RESOLVED'
and	name	= upper( '$pdb' )
group by
	name
;"

info "$db[$pdb] violations"
sqlplus_print_query "$violations"
LN

[[ $ro == no && $as_seed == no ]] && print_pdbs_status || true

if [[ $dataguard == yes && $count_stby_error -ne 0 ]]
then
	warning "When Dataguard server available :"
	warning "On server(s) ${stby_server_list[*]}"
	warning "Update tns alias : ~/plescripts/db/add_tns_alias.sh"
	warning "~/plescripts/db/create_trigger_open_stby_pdbs_ro.sql"
	warning "~/plescripts/db/create_trigger_start_pdb_services.sql"
	if [ $wallet == yes ]
	then
		warning "~/plescripts/db/add_sysdba_credential_for_pdb.sh"
	fi
	LN

	warning "From this server execute :"
	warning "~/plescripts/db/create_srv_for_dataguard.sh"
	LN
fi

[ $log == yes ] && script_stop ${ME##*/} $db || true
