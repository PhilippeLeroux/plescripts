#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

if command_exists crsctl
then
	typeset	-r	crs_used=yes
else
	typeset	-r	crs_used=no
fi

typeset -r	orcl_version=$(read_orcl_version)
if [ "$orcl_version" != "$oracle_release" ]
then
	warning "Bad Oracle Release"
	exec_cmd ~/plescripts/update_local_cfg.sh ORACLE_RELEASE="$orcl_version"

	info "Rerun with local config updated."
	exec_cmd $ME $PARAMS
	LN
	exit 0
fi

typeset	-r	orcl_release="$(cut -d. -f1-2<<<"$orcl_version")"
typeset		db=undef
typeset		sysPassword=$oracle_password

if [ $crs_used == yes ]
then
	typeset	automaticMemoryManagement=true
	typeset	data=DATA
	typeset	fra=FRA
else
	typeset	automaticMemoryManagement=true
	typeset	data=$orcl_fs_data
	typeset	fra=$orcl_fs_fra
fi

typeset	-i	totalMemory=0
typeset	-i	memoryMaxTarget=0
typeset		sga_target="0"
typeset		pga_aggregate_target="0"
if [[ $orcl_release == 12.2 ]]
then
	typeset -r set_param_totalMemory=no
else
	typeset -r set_param_totalMemory=yes
fi

function adjust_memory_parameters
{
	if [ $automaticMemoryManagement == true ]
	then
		if [ $set_param_totalMemory == yes ]
		then
			if [ $crs_used == yes ]
			then
				if [ $gi_count_nodes -gt 1 ]
				then
					totalMemory=$(to_mb $shm_for_db)
				else
					typeset -ri shm_max_mb=$(df -m /dev/shm|tail -1|awk '{print $2}')
					totalMemory=$(compute -i "$shm_max_mb - ($shm_max_mb*29)/100")
				fi
			else
				typeset -ri shm_max_mb=$(df -m /dev/shm|tail -1|awk '{print $2}')
				totalMemory=$(compute -i "$shm_max_mb - ($shm_max_mb*10)/100")
			fi
		else # Bug Oracle 12.2 totalMemory est ignoré.
			if [ $crs_used == yes ]
			then
				if [ $gi_count_nodes -gt 1 ]
				then
					memoryMaxTarget=$(to_mb $shm_for_db)
				else
					typeset -ri shm_max_mb=$(df -m /dev/shm|tail -1|awk '{print $2}')
					memoryMaxTarget=$(compute -i "$shm_max_mb - ($shm_max_mb*29)/100")
				fi
			else
				typeset -ri shm_max_mb=$(df -m /dev/shm|tail -1|awk '{print $2}')
				memoryMaxTarget=$(compute -i "$shm_max_mb - ($shm_max_mb*10)/100")
			fi
		fi
	else
		sga_target=$(($(to_mb $shm_for_db) - 80))m
		pga_aggregate_target=80m
	fi
}

adjust_memory_parameters

# L'ajustement de ces paramètres permettent d'éviter (ou au moins d'atténuer) les
# erreurs d'allocation mémoire lors de la création des schémas de démos.
case "$orcl_release" in
	12.1)
		# Avec des VMs à 2 512 Mb il n'est plus utile de définir ces paramètres.
		typeset	shared_pool_size="0"
		typeset	java_pool_size="0" #8M
		;;
	12.2|18.0)
		if [ $crs_used == yes ]
		then
			typeset	shared_pool_size="350M"
			typeset	java_pool_size="8M"
		else
			typeset	shared_pool_size="0"
			typeset	java_pool_size="0"
		fi
		;;
	*)
		error "Oracle Database '$orcl_release' invalid."
		LN
		exit 1
esac

typeset		templateName=General_Purpose.dbc
typeset		db_type=undef
typeset		node_list=undef
typeset		cdb=yes
typeset		lang=french
typeset		serverPoolName=undef
typeset		policyManaged=no
typeset		enable_flashback=yes
typeset		backup=yes
typeset		confirm="-confirm"
typeset	-i	redoSize=$db_redosize_mb
typeset	-i	fast_start_mttr_target=$db_fast_start_mttr_target

#	DEBUG :
typeset		create_database=yes

add_usage "-db=name"									"Database name."
add_usage "[-lang=$lang]"								"Language, ignored if NLS_LANG defined."
add_usage "[-sysPassword=$sysPassword]"
add_usage "[-automaticMemoryManagement=$automaticMemoryManagement]" "false|true (1)"
if [ $set_param_totalMemory == yes ]
then
	add_usage "[-totalMemory=$totalMemory]"				"Unit Mb, 0 to disable. (2)"
else	# utiliser memory_target avec le crs fait planter la création de la base.
		# Avec le crs 800m est lu 80m
	add_usage "[-memoryMaxTarget=$memoryMaxTarget]"		"Unit Mb, 0 to disable. (2)"
fi
# 12.1 Quand le grid est utilisé il faut obligatoirement présicer une valeur
# minimum de 256M sinon la création échoue, sur un FS mettre 0 est OK
add_usage "[-shared_pool_size=$shared_pool_size]"		"0 to disable. (2) (6)"
add_usage "[-cdb=$cdb]"									"yes|no"
add_usage "[-redoSize=$redoSize]"						"Redo size Mb."
add_usage "[-fast_start_mttr_target=$fast_start_mttr_target]" "0 to disable."
add_usage "[-data=$data]"
add_usage "[-fra=$fra]"
add_usage "[-templateName=$templateName]"
add_usage "[-db_type=SINGLE|RAC|RACONENODE]"			"(3)"
add_usage "[-policyManaged]"							"Database Policy Managed. (4)"
add_usage "[-serverPoolName=name]"						"pool name. (5)"
add_usage "[-enable_flashback=$enable_flashback]"		"yes|no"
add_usage "[-no_backup]"								"No backup."

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)

\t1 : with CRS default value is false, else true.

\t2 : disabled with -automaticMemoryManagement=true.

\t3 : db_type auto for single or RAC.
\t    To create RAC One node used -db_type=RACONENODE
\t    RAC One node service : ron_$(hostname -s)

\t4 : Default pool name : poolAllNodes

\t5 : Enable flag -policyManaged

\t6 : 12.2.0.1 minimum 335M

\tDebug flag :
\t	-skip_db_create : skip create database.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-y)
			confirm=""
			shift
			;;

		-automaticMemoryManagement=*)
			automaticMemoryManagement=${1##*=}
			shift
			;;

		-totalMemory=*)
			totalMemory=${1##*=}
			shift
			;;

		-memoryMaxTarget=*)
			memoryMaxTarget=${1##*=}
			shift
			;;

		-db=*)
			db=$(to_upper ${1##*=})
			lower_db=$(to_lower $db)
			shift
			;;

		-redoSize=*)
			redoSize=${1##*=}
			shift
			;;

		-fast_start_mttr_target=*)
			fast_start_mttr_target=${1##*=}
			shift
			;;

		-sysPassword=*)
			sysPassword=${1##*=}
			shift
			;;

		-shared_pool_size=*)
			shared_pool_size=${1##*=}
			shift
			;;

		-data=*)
			data=${1##*=}
			shift
			;;

		-fra=*)
			fra=${1##*=}
			shift
			;;

		-templateName=*)
			templateName=${1##*=}
			shift
			if [ ! -f $ORACLE_HOME/assistants/dbca/templates/${templateName} ]
			then
				echo "Template file '$templateName' not exists"
				echo "Templates availables : "
				(	cd $ORACLE_HOME/assistants/dbca/templates
					ls -rtl *dbc
				)
				exit 1
			fi
			;;

		-db_type=*)
			db_type=$(to_upper ${1##*=})
			shift
			;;

		-cdb=*)
			cdb=$(to_lower ${1##*=})
			shift
			;;

		-lang=*)
			lang=$(to_lower ${1##*=})
			shift
			;;

		-serverPoolName=*)
			serverPoolName=${1##*=}
			shift
			;;

		-policyManaged)
			policyManaged=yes
			shift
			;;

		-enable_flashback=*)
			enable_flashback=${1##*=}
			shift
			;;

		-no_backup)
			backup=no
			shift
			;;

		-skip_db_create)
			create_database=no
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

#	Return 0 if server pool $1 exists, else 1
function serverpool_exists
{
	typeset -r serverPoolName=$1

	info "Test if server pool $serverPoolName exists :"
	exec_cmd -ci "srvctl status srvpool -serverpool $serverPoolName"
	res=$?
	LN
	return $res
}

function make_dbca_args
{
	add_dynamic_cmd_param "-createDatabase -silent"

	add_dynamic_cmd_param "-databaseConfType $db_type"
	if [ $db_type == RACONENODE ]
	then
		typeset -r	ron_service="ron_$(hostname -s)"
		add_dynamic_cmd_param "    -RACOneNodeServiceName $ron_service"
	fi

	[ "$node_list" != undef ] && add_dynamic_cmd_param "-nodelist $node_list"

	if [ $serverPoolName != undef ]
	then
		add_dynamic_cmd_param "-policyManaged"
		if [ $cdb == yes ]
		then
			if ! serverpool_exists $serverPoolName
			then
				add_dynamic_cmd_param "    -createServerPool"
			fi
			add_dynamic_cmd_param "    -serverPoolName $serverPoolName"
		fi
	fi

	add_dynamic_cmd_param "-gdbName $db"
	add_dynamic_cmd_param "-characterSet AL32UTF8"

	if [ $crs_used == yes ]
	then
		add_dynamic_cmd_param "-storageType ASM"
		add_dynamic_cmd_param "    -diskGroupName     $data"
		add_dynamic_cmd_param "    -recoveryGroupName $fra"
	else
		add_dynamic_cmd_param "-datafileDestination     $data"
		add_dynamic_cmd_param "-recoveryAreaDestination $fra"
	fi

	add_dynamic_cmd_param "-templateName $templateName"

	if [ "$cdb" = yes ]
	then
		add_dynamic_cmd_param "-createAsContainerDatabase true"
	else
		add_dynamic_cmd_param "-createAsContainerDatabase false"
	fi

	add_dynamic_cmd_param "-sysPassword    $sysPassword"
	add_dynamic_cmd_param "-systemPassword $sysPassword"
	add_dynamic_cmd_param "-redoLogFileSize $redoSize"

	typeset initParams="-initParams threaded_execution=true"

	if [ "$automaticMemoryManagement" == true ]
	then
		add_dynamic_cmd_param "-automaticMemoryManagement true"
		if [ $totalMemory -ne 0 ]
		then
			add_dynamic_cmd_param "-totalMemory $totalMemory"
			if [[ $crs_used == yes && "$shm_for_db" != "0" && $totalMemory -gt $(to_mb $shm_for_db) ]]
			then
				warning "totalMemory (${totalMemory}M) > shm_for_db ($shm_for_db)"
				LN
			fi
		elif [[ $memoryMaxTarget -ne 0 ]]
		then # Ne doit être définie que pour une base single : bug Oracle.
			if [[ $crs_used == yes && "$shm_for_db" != "0" && $memoryMaxTarget -gt $(to_mb $shm_for_db) ]]
			then
				warning "memoryMaxTarget (${memoryMaxTarget}M) > shm_for_db ($shm_for_db)"
				LN
			fi

			initParams="$initParams,memory_target=${memoryMaxTarget}m"
		fi
	else
		add_dynamic_cmd_param "-automaticMemoryManagement false"
		if [ $sga_target != "0" ]
		then
			initParams="$initParams,memory_target=0,sga_target=$sga_target,pga_aggregate_target=$pga_aggregate_target"
		fi
	fi

	if [ "$shared_pool_size" != "0" ]
	then
		initParams="$initParams,shared_pool_size=$shared_pool_size"
	fi

	if [ "$java_pool_size" != "0" ]
	then
		initParams="$initParams,java_pool_size=$java_pool_size"
	fi

	if [ $crs_used == no ]
	then # sur FS il faut activer les asynch I/O & co.
		initParams="$initParams,filesystemio_options=setall"
	fi

	# Je sécurise le truc.
	initParams="$initParams,db_block_checksum=full"

	if [ $fast_start_mttr_target -ne 0 ]
	then
		initParams="$initParams,fast_start_mttr_target=$fast_start_mttr_target"
	fi

	if [ x"$NLS_LANG" == x ]
	then
		case $lang in
			french)
				initParams="$initParams,nls_language=FRENCH,NLS_TERRITORY=FRANCE"
				;;
		esac
	fi

	if [ $crs_used == no ]
	then # Bug ou pas ? même sur FS utilisation d'OMF.
		initParams="$initParams,db_create_file_dest=$data"
	fi

	add_dynamic_cmd_param "$initParams"
}

#	Test si l'installation est de type RAC ou SINGLE.
#	Se base sur olsnodes.
#	Initialise les variables :
#		- node_list : pour un RAC contiendra tous les nœuds ou undef.
#		- db_type : SINGLE ou RAC si n'est pas définie.
function load_node_list_and_update_dbtype
{
	if command_exists olsnodes
	then
		typeset -i count_nodes=0
		while read node_name
		do
			if [ $count_nodes -eq 0 ]
			then
				node_list=$node_name
			else
				node_list=${node_list}","$node_name
			fi
			((++count_nodes))
		done<<<"$(olsnodes)"

		[[ $db_type == undef && $count_nodes -gt 1 ]] && db_type=RAC || true
	fi

	[ $db_type == undef ] && db_type=SINGLE || true

	#	Note sur un single olsnodes existe mais ne retourne rien.
	[ x"$node_list" == x ] && node_list=undef || true
}

#	Création de la base.
#	Ne rends pas la main sur une erreur.
function create_database
{
	make_dbca_args

	exec_cmd "rm -rf $ORACLE_BASE/cfgtoollogs/dbca/$DB"
	LN

	info "Create database $db"
	info "   Backup database : $backup"
	LN

	exec_dynamic_cmd $confirm dbca
	typeset -ri	dbca_return=$?
	if [ $dbca_return -eq 0 ]
	then
		info "dbca [$OK]"
		LN
	else
		info "dbca [$KO] return $dbca_return"
		exit 1
	fi
}

function update_rac_oratab
{
	[[ $policyManaged == "yes" || $db_type == "RACONENODE" ]] && prefixInstance=${prefixInstance}_

	for node in $( sed "s/,/ /g" <<<"$node_list" )
	do
		line_separator
		exec_cmd "ssh -t oracle@${node} \". .profile; ~/plescripts/db/update_rac_oratab.sh -prefixInstance=$prefixInstance\""
		LN
	done
}

#	La fonction n'est plus utilisée, dbca ne créant plus de PDB ça ne pose pas
#	de problème.
#	Mon glogin fait planter la création de la PDB.
function remove_glogin
{
	LN
	info "Remove glogin.sql"
	execute_on_all_nodes "rm -f \$ORACLE_HOME/sqlplus/admin/glogin.sql"
	LN
}

function copy_glogin
{
	line_separator
	info "Copy glogin.sql"
	if [ "${db_type:0:3}" == "RAC" ]
	then
		for node in $( sed "s/,/ /g" <<<"$node_list" )
		do
			if [ $node != $(hostname -s) ]
			then
				exec_cmd scp $node:~/plescripts/oracle_preinstall/glogin.sql	\
										$ORACLE_HOME/sqlplus/admin/glogin.sql
				LN
			fi
		done
	fi

	exec_cmd cp ~/plescripts/oracle_preinstall/glogin.sql	\
										$ORACLE_HOME/sqlplus/admin/glogin.sql
	LN
}

function fsdb_enable_autostart
{
	line_separator
	info "Enable auto start for database"
	exec_cmd "sed \"s/^\(${db:0:8}.*\):N/\1:Y/\" /etc/oratab > /tmp/ot"
	exec_cmd "cat /tmp/ot > /etc/oratab"
	exec_cmd "rm /tmp/ot"
	LN
}

function adjust_policymanaged_parameters
{
	#	Si Policy Managed création du pool 'poolAllNodes' si aucun pool de précisé.
	[[ $policyManaged == yes && $serverPoolName == undef ]] && serverPoolName=poolAllNodes || true
	[ $serverPoolName != undef ] && policyManaged=yes || true
}

function create_links
{
	exec_cmd "~/plescripts/db/create_links.sh -db=$db"
	LN

	if [ $gi_count_nodes -gt 1 ]
	then
		for node in $gi_node_list
		do
			exec_cmd "ssh $node '. .bash_profile && plescripts/db/create_links.sh -db=$db'"
			LN
		done
	fi
}

# Les paramètres doivent être modifiés sur chaque instance ou au niveau du spfile.
# La base sera redémarrée plus tard.
function rac12cR2_adjust_poolsize
{
	if [[ "$shared_pool_size" != "0" ]]
	then
		line_separator
		function adjust_params
		{
			set_sql_cmd "alter system set shared_pool_size=$shared_pool_size scope=spfile sid='*';"
			if [ "$java_pool_size" != "0" ]
			then
				set_sql_cmd "alter system set java_pool_size=$java_pool_size scope=spfile sid='*';"
			fi
		}
		sqlplus_cmd "$(adjust_params)"
		LN
	fi
}

function workaround_bug_9040676
{
	if [[ "${db_type:0:3}" == "RAC" && $orcl_version == "12.1.0.2" ]]
	then
		line_separator
		info "Bug 9040676 : MMON ACTION POLICY VIOLATION. 'BLOCK CLEANOUT OPTIM, UNDO SEGMENT SCAN' (ORA-12751)"
		sqlplus_cmd "$(set_sql_cmd "alter system set \"_smu_debug_mode\"=134217728 scope=both sid='*';")"
		LN
	fi
}

function adjust_FRA_size
{
	line_separator
	info "Adjust FRA size"
	if [ $crs_used == yes ]
	then
		sqlplus_cmd "$(set_sql_cmd "@$HOME/plescripts/db/sql/adjust_recovery_size.sql")"
		LN
	else
		typeset -i disk_size=$(df --block-size=$((1024*1024)) /$orcl_fra_fs_disk | tail -1 | awk '{ print $2 }')
		typeset -i fra_size=$(compute -i "$disk_size * 0.9")
		sqlplus_cmd "$(set_sql_cmd "alter system set db_recovery_file_dest_size=${fra_size}M scope=both sid='*';")"
		LN
	fi
}

function check_tuned_profile
{
	if [ "$(tuned-adm active | awk '{ print $4 }')" == "ple-hporacle" ]
	then
		error "Tuned profile active is ple-hporacle (Huge page configuration)"
		error "With user root, activate profile ple-oracle : "
		error "$ su - root -c \"tuned-adm profile ple-oracle\""
		LN
		exit 1
	fi
}

function enable_flashback
{
	line_separator
	info "Enable flashback :"
	function alter_database_flashback_on
	{
		set_sql_cmd "whenever sqlerror exit 1;"
		set_sql_cmd "alter database flashback on;"
		set_sql_cmd "alter system switch logfile;"
	}
	sqlplus_cmd "$(alter_database_flashback_on)"
	[ $? -ne 0 ] && exit 1 || true
	LN
}

function next_instructions
{
	typeset -r instance=$(ps -ef |  grep [p]mon | grep -vE "MGMTDB|\+ASM" | cut -d_ -f3-4)
	line_separator

	info "To create a pdb use script create_pdb.sh :"
	info "$ export ORACLE_SID=$instance"
	info "$ ./create_pdb.sh -db=$db -pdb=pdb01"
	LN

	if [ "$cfg_dataguard" == yes ]
	then
		info "To create dataguard execute :"
		info "$ export ORACLE_SID=$instance"
		info "$ cd ~/plescripts/db/stby/"
		info "$ ./create_dataguard.sh"
		LN
	fi
}

#	============================================================================
#	MAIN
#	============================================================================
exit_if_param_undef		db								"$str_usage"
exit_if_param_invalid	cdb					"yes no"	"$str_usage"
exit_if_param_invalid	enable_flashback	"yes no"	"$str_usage"
if [ $db_type != undef ]
then
	exit_if_param_invalid	db_type "SINGLE RAC RACONENODE"	"$str_usage"
fi

script_start

ple_enable_log -params $PARAMS

adjust_memory_parameters

adjust_policymanaged_parameters

check_tuned_profile

stats_tt start create_$lower_db

typeset prefixInstance=${db:0:8}
case ${db:${#db}-2} in
	01|02)
		typeset	-r	dbid=$(to_lower ${db:0:${#db}-2})
		if cfg_exists $dbid use_return_code
		then
			cfg_load_node_info $dbid 1
		fi
		;;
	*)
		if cfg_exists $db use_return_code
		then
			cfg_load_node_info $db 1
			if [[ "$cfg_dataguard" == yes && "${db:${#db}-2}" != "01" ]]
			then
				error "Dataguard db name invalid, must be like ${db}01"
				LN
				exit 1
			fi
		fi
esac

load_node_list_and_update_dbtype

#remove_glogin

if [ $crs_used == no ]
then
	info "Start listener"
	exec_cmd -c lsnrctl start
	LN
fi

[ $create_database == yes ] && create_database || true

[ "${db_type:0:3}" == "RAC" ] && update_rac_oratab || true

create_links

line_separator
ORACLE_SID=$(~/plescripts/db/get_active_instance.sh)
if [ x"$ORACLE_SID" == x ]
then
	error "$(hostname -s) : cannot define ORACLE_SID ?"
	exit 1
fi

load_oraenv_for $ORACLE_SID

workaround_bug_9040676

wait_if_high_load_average 5

[ $crs_used == no ] && fsdb_enable_autostart || true

# 12cR2 et plus même config pour le momment.
[ $orcl_release != 12.1 ] && rac12cR2_adjust_poolsize || true

if [ $crs_used == yes ]
then
	# Util avec le Grid Infra uniquement.
	# Parfois l'arrêt de la base échoue si le Load Average est trop important.
	TEST_HIGH_LAVG=enable
	wait_if_high_load_average 5
	TEST_HIGH_LAVG=disable
else
	wait_if_high_load_average 5
fi

adjust_FRA_size

line_separator
info "Enable archivelog :"
info "Instance : $ORACLE_SID"
exec_cmd "~/plescripts/db/enable_archive_log.sh -db=$db"
LN

if [ $enable_flashback == yes ] && is_oracle_enterprise_edition
then
	wait_if_high_load_average 4

	enable_flashback
elif [ $enable_flashback == yes ]
then
	info "Flashback not supported with Oracle Standard Edition."
	LN
fi

copy_glogin

if [ $crs_used == yes ]
then
	line_separator
	info "Database config :"
	exec_cmd "srvctl config database -db $lower_db"
	LN

	line_separator
	exec_cmd "crsctl stat res ora.$lower_db.db -t"
	LN
else
	line_separator
	info "Listener status"
	exec_cmd -c lsnrctl status
	LN
fi

line_separator
info "Configure RMAN"
exec_cmd "~/plescripts/db/configure_backup.sh"
LN

if [ $backup == yes ]
then
	line_separator
	info "Backup database"
	exec_cmd -c "~/plescripts/db/image_copy_backup.sh"
	LN
fi

stats_tt stop create_$lower_db

script_stop $ME $lower_db
LN

next_instructions
