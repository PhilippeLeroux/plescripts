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
typeset		wallet=${WALLET:-$(enable_wallet $orcl_release)}
typeset		sampleSchema=no
typeset		is_seed=no
typeset		admin_user=pdbadmin
typeset		admin_pass=$oracle_password

typeset		log=yes

add_usage "-db=name"			"Database name."
add_usage "-pdb=name"			"PDB name."
add_usage "[-sampleSchema=$sampleSchema]"	"yes|no"
add_usage "[-is_seed]"			"Create seed pdb."
add_usage "[-from_pdb=name]"	"Clone from pdb 'name'"
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

		-is_seed)
			is_seed=yes
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

function sql_lspdbs
{
typeset query=\
"select
	i.instance_name
,	case when c.name = upper( '$pdb' ) then '*'||c.name||'*' else c.name end name
,	c.open_mode
,	round( c.total_size / 1024 / 1024, 0 ) \"Size (Mb)\"
,	c.recovery_status
,	nvl(pss.state,'NOT SAVED') \"State\"
from
	gv\$containers c
	inner join gv\$instance i
		on  c.inst_id = i.inst_id
	left join dba_pdb_saved_states pss
		on	c.con_uid = pss.con_uid
		and	c.guid = pss.guid
order by
	c.name
,	i.instance_name;"

	echo "set lines 150"
	echo "col instance_name	for	a10		head \"Instance\""
	echo "col name			for	a12		head \"PDB name\""
	echo "col open_mode					head \"Open mode\""
	echo "$query"
}

function print_pdbs_status
{
	info "Primary $db status :"
	sqlplus_cmd "$(sql_lspdbs)"
	LN

	if [ $dataguard == yes ]
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
				sqlplus_cmd_with $conn_string "$(sql_lspdbs)"
				LN
			done
		fi
	fi
}

function clone_pdb_pdbseed
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
	# $1 pdb name
	function ddl_clone_from_pdb
	{
		set_sql_cmd "whenever sqlerror exit 1;"
		if [ $dataguard == yes ]
		then
			# Sur un Dataguard si le PDB est RW alors la synchro est HS
			# Il faut que le PDB soit RO pour être clonable : BUG or not BUG ??
			# Testé sur la 12.2 c'est la même chose.
			set_sql_cmd "alter pluggable database $1 close immediate instances=all;"
			set_sql_cmd "alter pluggable database $1 open read only instances=all;"
		fi
		set_sql_cmd "create pluggable database $pdb from $1 standbys=all;"
		if [ $dataguard == yes ]
		then
			set_sql_cmd "alter pluggable database $1 close immediate instances=all;"
			set_sql_cmd "alter pluggable database $1 open instances=all;"
		fi
	}
	info "Clone $pdb from $1"
	if [ $dataguard == yes ]
	then
		warning "Dataguard bug : $1 must be reopen RO"
		LN
	fi
	sqlplus_cmd "$(ddl_clone_from_pdb $1)"
	[ $? -ne 0 ] && exit 1 || true
}

# $1 pdb name
# Attention pour pouvoir ouvrir en RO un pdb, il doit d'abord avoir été ouvert
# en RW.
function pdb_seed_open_read_only
{
	typeset pdb_name=$1
	#	Sur un dataguard le PDB doit être ouvert pour être clonable.
	#	Il sera donc un RO comme PDB$SEED.
	set_sql_cmd "alter pluggable database $pdb_name close instances=all;"
	set_sql_cmd "whenever sqlerror exit 1;"

	set_sql_prompt "Open seed pdb $pdb_name RO"
	set_sql_cmd "alter pluggable database $pdb_name open read only instances=all;"
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

# TODO : utiliser 'service_name_convert' de 'create pluggable ....' ??  et avec
# le CRS sa donne quoi ??
function create_pdb_services
{
	[[ $crs_used == no ]] && create_database_trigger_open_stby_pdb || true

	create_database_trigger_start_pdb_services

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

[ $is_seed == yes ] && wallet=no || true

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
fi
LN

wait_if_high_load_average

line_separator
[ $from_pdb == default ] && clone_pdb_pdbseed || clone_from_pdb $from_pdb
LN

wait_if_high_load_average

for stby in ${physical_list[*]}
do
	exec_cmd "dgmgrl -silent sys/$oracle_password 'show database ${stby}'"
	LN
done

if [ $from_pdb != default ]
then
	info "Remove services cloned from $from_pdb on $pdb"
	sqlplus_cmd "$(sqlcmd_remove_services_from_cloned_pdb)"
	LN
fi

wait_if_high_load_average

info "Open RW $db[$pdb] and save state."
# Pour ouvrir un PDB RO il faut d'abord l'ouvrir en RW, sinon l'ouverture échoue.
# si $is_seed == yes l'ouverture de la base en RO ne posera pas de problème.
sqlplus_cmd "$(open_pdb_and_save_state $pdb)"
LN

if [[ $dataguard == yes && $count_stby_error -eq 0 && ${#physical_list[*]} -ne 0 ]]
then
	stby_create_temporary_file
fi

if [ $is_seed == yes ]
then
	info "Open read only seed : $db[$pdb]"
	sqlplus_cmd "$(pdb_seed_open_read_only $pdb)"
	LN
fi

print_pdbs_status

wait_if_high_load_average

[ $is_seed == no ] && create_pdb_services || true

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

[ $is_seed == no ] && print_pdbs_status || true

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
