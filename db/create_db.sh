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

#	12c ajustement :
#	ORA-04031: unable to allocate 1015832 bytes of shared memory ("shared pool","unknown object","PDB Dynamic He","Alloc/Free SWRF Metric CHBs")
#	Error while executing "/u01/app/oracle/12.1.0.2/dbhome_1/rdbms/admin/dbmssml.sql".   Refer to "/u01/app/oracle/cfgtoollogs/dbca/NEPTUNE/dbmssml0.log" for more details.   Error in Process: /u01/app/oracle/12.1.0.2/dbhome_1/perl/bin/perl
#	DBCA_PROGRESS : DBCA Operation failed.
#	Pour éviter ce message d'erreur utiliser le paramètre -shared_pool_size=256M
#	Cf select name, round( bytes/1024/1024, 2) "Size Mb" from v$sgainfo order by 2 desc;

typeset	-r	orcl_release="$(read_orcl_release)"
typeset		db=undef
typeset		sysPassword=$oracle_password
typeset	-i	totalMemory=0
[[ $gi_count_nodes -ne 1 ]] && totalMemory=$(to_mb $shm_for_db) || true
case "$orcl_release" in
	12.1)
		typeset	shared_pool_size="344M"	# Strict minimum 256M
		typeset	pga_aggregate_limit="1256M"
		;;
	12.2)
		typeset	shared_pool_size="344M"
		typeset	pga_aggregate_limit="2048M"
		;;
	*)
		error "Oracle Database '$orcl_release' invalid."
		LN
		exit 1
esac
typeset		data=DATA
typeset		fra=FRA
typeset		templateName=General_Purpose.dbc
typeset		db_type=undef
typeset		node_list=undef
typeset		cdb=yes
typeset		lang=french
typeset		pdb=undef
typeset		serverPoolName=undef
typeset		policyManaged=no
typeset		enable_flashback=yes
typeset		backup=yes
typeset		confirm="-confirm"
typeset	-i	redoSize=64	# Unit Mb
typeset		sampleSchema=no
if [ $orcl_release == 12.1 ]
then
	typeset		wallet=yes
elif test_if_cmd_exists crsctl
then # Impossible de démarrer la base avec le wallet.
	typeset		wallet=no
else # Sur FS pas de problème.
	typeset		wallet=yes
fi

#	DEBUG :
typeset		create_database=yes

add_usage "-db=name"								"Database name."
add_usage "[-lang=$lang]"							"Language."
add_usage "[-sampleSchema=$sampleSchema]"			"yes|no (pdb only)"
add_usage "[-sysPassword=$sysPassword]"
add_usage "[-totalMemory=$totalMemory]"				"Unit Mb, 0 to disable."
# 12.1 Quand le grid est utilisé il faut obligatoirement présicer une valeur
# minimum de 256M sinon la création échoue, sur un FS mettre 0 est OK
add_usage "[-shared_pool_size=$shared_pool_size]"	"0 to disable this setting (6)"
# 12.1 sur un RAC fixer une limite est important.
add_usage "[-pga_aggregate_limit=$pga_aggregate_limit" "0 to disable this setting (7)"
add_usage "[-cdb=$cdb]"								"yes|no (1)"
add_usage "[-pdb=name]"								"pdb name (2)"
add_usage "[-wallet=$wallet]"						"yes|no. yes : Wallet Manager for pdb connection."
add_usage "[-redoSize=$redoSize]"					"Redo size Mb."
add_usage "[-data=$data]"
add_usage "[-fra=$fra]"
add_usage "[-templateName=$templateName]"
add_usage "[-db_type=SINGLE|RAC|RACONENODE]"		"(3)"
add_usage "[-policyManaged]"						"Database Policy Managed (4)"
add_usage "[-serverPoolName=name]"					"pool name. (5)"
add_usage "[-enable_flashback=$enable_flashback]"	"yes|no"
add_usage "[-no_backup]"							"No backup."

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)

\t1 : -cdb=yes and -pdb not defined : -pdb=pdb01

\t2 : -pdb defined : -cdb set to yes.
\t	-pdb=no : do not create a pdb, only cdb.
\t	Add 2 services : pdb name postfixed by _oci & _java

\t3 : db_type auto for single or RAC.
\t	To create RAC One node used -db_type=RACONENODE
\t	RAC One node service : ron_$(hostname -s)

\t4 : Default pool name : poolAllNodes

\t5 : Enable flag -policyManaged

\t6 : 12.2.0.1 minimum 335M

\t7 : RAC 12.2.0.1 minimum 2048M

\tDebug flag :
\t	-skip_db_create : skip create database, add -pdb=no to skip create pdb
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

		-totalMemory=*)
			totalMemory=${1##*=}
			shift
			;;

		-db=*)
			db=$(to_upper ${1##*=})
			lower_db=$(to_lower $db)
			shift
			;;

		-sampleSchema=*)
			sampleSchema=${1##*=}
			shift
			;;

		-wallet=*)
			wallet=$(to_lower ${1##*=})
			shift
			;;

		-redoSize=*)
			redoSize=${1##*=}
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
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

		-pga_aggregate_limit=*)
			pga_aggregate_limit=${1##*=}
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

		if [ 0 -eq 1 ]; then # Mutualisation du code de création des PDBs.
		if [ "$pdb" != undef ]
		then
			add_dynamic_cmd_param "    -numberOfPDBs     $numberOfPDBs"
			add_dynamic_cmd_param "    -pdbName          $pdb"
			add_dynamic_cmd_param "    -pdbAdminPassword $sysPassword"
		fi
		fi # [ 0 -eq 1 ]; then
	else
		add_dynamic_cmd_param "-createAsContainerDatabase false"
	fi

	add_dynamic_cmd_param "-sysPassword    $sysPassword"
	add_dynamic_cmd_param "-systemPassword $sysPassword"
	add_dynamic_cmd_param "-redoLogFileSize $redoSize"

	if [ $totalMemory -ne 0 ]
	then
		add_dynamic_cmd_param "-totalMemory $totalMemory"
		if [[ "$shm_for_db" != "0" && $totalMemory -gt $(to_mb $shm_for_db) ]]
		then
			warning "totalMemoy (${totalMemory}M) > shm_for_db ($shm_for_db)"
		fi
	fi

	typeset initParams="-initParams threaded_execution=true"

	if [ $crs_used == no ]
	then # sur FS il faut activer les asynch I/O
		initParams="$initParams,filesystemio_options=setall"
	fi

	if [[ "${db_type:0:3}" == RAC && $pga_aggregate_limit != "0" ]]
	then
		# set pga_aggregate_limit for test not prod.
		initParams="$initParams,pga_aggregate_limit=$pga_aggregate_limit"
	fi

	case $lang in
		french)
			initParams="$initParams,nls_language=FRENCH,NLS_TERRITORY=FRANCE"
			;;
	esac

	if [[ "$shared_pool_size" != "0" ]]
	then
		initParams="$initParams,shared_pool_size=$shared_pool_size"
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
	if test_if_cmd_exists olsnodes
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

# print to stdout yes or no
function test_if_crs_used
{
	if test_if_cmd_exists crsctl
	then
		echo yes
	else
		echo no
	fi
}

#	Création de la base.
#	Ne rends pas la main sur une erreur.
function create_database
{
	make_dbca_args

	exec_cmd "rm -rf $ORACLE_BASE/cfgtoollogs/dbca/$DB"
	LN

	info "Create database $db"
	if [ $pdb != undef ]
	then
		info "   - Create pdb            : $pdb"
		info "   - Wallet Manager        : $wallet"
		info "   - Create sample schemas : $sampleSchema"
	fi
	info "   - Backup database       : $backup"
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

function adjust_parameters
{
	[[ $cdb == yes && $pdb == undef ]] && pdb=pdb01 || true
	[ $pdb == no ] && pdb=undef || true

	if [ $pdb != undef ]
	then
		numberOfPDBs=1
	else
		sampleSchema=no
	fi

	#	Si Policy Managed création du pool 'poolAllNodes' si aucun pool de précisé.
	[[ $policyManaged == yes && $serverPoolName == undef ]] && serverPoolName=poolAllNodes || true
	[ $serverPoolName != undef ] && policyManaged=yes || true
}

function next_instructions
{
	if cfg_exists $db use_return_code >/dev/null 2>&1
	then
		cfg_load_node_info $db 1
		if [[ "$cfg_standby" != none	&& $(dataguard_config_available) == no
										&& ! -d $cfg_path_prefix/$cfg_standby ]]
		then
			info "From virtual-host $client_hostname execute :"
			info "$ cd ~/plescripts/database_servers"
			typeset params
			[ $crs_used == no ] && params="-storage=FS" || true
			info "$ ./define_new_server.sh -db=$cfg_standby -standby=$(to_lower $db) -rel=$orcl_release $params"
			LN
		fi
	fi
}

#	============================================================================
#	MAIN
#	============================================================================
ple_enable_log

script_banner $ME $*

script_start

exit_if_param_undef		db				"$str_usage"
exit_if_param_invalid	cdb "yes no"	"$str_usage"
if [ $db_type != undef ]
then
	exit_if_param_invalid	db_type "SINGLE RAC RACONENODE"	"$str_usage"
fi
exit_if_param_invalid	enable_flashback	"yes no"	"$str_usage"
exit_if_param_invalid	sampleSchema		"yes no"	"$str_usage"
exit_if_param_invalid	wallet				"yes no"	"$str_usage"

adjust_parameters

stats_tt start create_$lower_db

typeset prefixInstance=${db:0:8}

load_node_list_and_update_dbtype

typeset -r crs_used=$(test_if_crs_used)

if [[ $crs_used == no && "$data" == DATA && "$fra" == FRA ]]
then
	data=$ORCL_FS_DATA
	fra=$ORCL_FS_FRA
fi

remove_glogin

if [ $crs_used == no ]
then
	info "Start listener"
	exec_cmd -c lsnrctl start
	LN
fi

[ $create_database == yes ] && create_database || true

[ "${db_type:0:3}" == "RAC" ] && update_rac_oratab || true

line_separator
ORACLE_SID=$(~/plescripts/db/get_active_instance.sh)
if [ x"$ORACLE_SID" == x ]
then
	error "Cannot define ORACLE_SID ?"
	exit 1
fi

load_oraenv_for $ORACLE_SID

if [[ "${db_type:0:3}" == "RAC" && $oracle_release == "12.1.0.2" ]]
then
	info "Bug 9040676 : MMON ACTION POLICY VIOLATION. 'BLOCK CLEANOUT OPTIM, UNDO SEGMENT SCAN' (ORA-12751)"
	sqlplus_cmd "$(set_sql_cmd "alter system set \"_smu_debug_mode\"=134217728 scope=both sid='*';")"
fi

[ $crs_used == no ] && fsdb_enable_autostart || true

line_separator
info "Adjust FRA size"
if [ $crs_used == yes ]
then
	sqlplus_cmd "$(set_sql_cmd "@$HOME/plescripts/db/sql/adjust_recovery_size.sql")"
	LN
else
	typeset -i disk_size=$(to_mb $(df -h /$ORCL_FRA_FS_DISK | tail -1 | awk '{ print $2 }'))
	typeset -i fra_size=$(compute -i "$disk_size * 0.9")
	sqlplus_cmd "$(set_sql_cmd "alter system set db_recovery_file_dest_size=${fra_size}M scope=both sid='*';")"
	LN
fi

line_separator
info "Enable archivelog :"
info "Instance : $ORACLE_SID"
exec_cmd "~/plescripts/db/enable_archive_log.sh -db=$db"
LN

if [ $enable_flashback == yes ]
then
	line_separator
	info "Enable flashback :"
	function alter_database_flashback_on
	{
		set_sql_cmd "whenever sqlerror exit 1;"
		set_sql_cmd "alter database flashback on;"
	}
	sqlplus_cmd "$(alter_database_flashback_on)"
	[ $? -ne 0 ] && exit 1 || true
	LN
fi

copy_glogin

if [[ $cdb == yes && $pdb != undef ]]
then
	exec_cmd ~/plescripts/db/create_pdb.sh						\
								-db=$db							\
								-pdb=$pdb						\
								-wallet=$wallet					\
								-sampleSchema=$sampleSchema		\
								-nolog
fi

if [ $crs_used == yes ]
then
	line_separator
	info "Database config :"
	exec_cmd "srvctl config database -db $lower_db"
	LN
	exec_cmd "srvctl status service -db $lower_db"
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
	info "Backup database"
	exec_cmd "~/plescripts/db/image_copy_backup.sh"
	LN
fi

stats_tt stop create_$lower_db

script_stop $ME $lower_db
LN

next_instructions
