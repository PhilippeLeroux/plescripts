#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
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

typeset		db=undef
typeset		sysPassword=$oracle_password
typeset	-i	totalMemory=$(to_mb $shm_for_db)
[ $totalMemory -eq 0 ] && totalMemory=640
typeset		shared_pool_size=default
typeset		data=DATA
typeset		fra=FRA
typeset		templateName=General_Purpose.dbc
typeset		db_type=undef
typeset		node_list=undef
typeset		cdb=yes
typeset		lang=french
typeset		pdbName=undef
typeset		serverPoolName=undef
typeset		policyManaged=no
typeset		enable_flashback=yes
typeset		backup=yes
typeset		confirm="-confirm"

typeset		skip_db_create=no

typeset -r str_usage=\
"Usage : $ME
	-db=<str>
	[-lang=$lang]
	[-sysPassword=$sysPassword]
	[-totalMemory=$totalMemory] Unit Mb
	[-shared_pool_size=<str>]	Préciser l'unité, par défaut 256M
	[-cdb=$cdb]	(yes/no)	(1)
	[-pdbName=<str>]	(2)
	[-data=$data]
	[-fra=$fra]
	[-templateName=$templateName]
	[-db_type=SINGLE|RAC|RACONENODE]	(3)
	[-policyManaged]  : créer une base en 'Policy Managed'	(4)
	[-serverPoolName=<str>] : nom du pool à utiliser, s'il n'existe pas il sera créée. (5)
	[-enable_flashback=$enable_flashback] : yes|no
	[-no_backup]      : Pas de backup après création de la base.

	1 : Si vaut yes et que -pdbName n'est pas précisé alors pdbName == db || 01
	    Le service de la pdb sera : pdb || db || 01
		Pour ne pas créer de pdb utiliser -pdbName=no

	2 : Si -pdbName est précisé -cdb vaut automatiquement yes

	3 : Si db_type n'est pas préciser il sera déterminer en fonction du nombre
	    de nœuds, si 1 seul nœud c'est SINGLE sinon c'est RAC.
	    Donc pour créer un RAC One Node database il faut impérativement le préciser !
		Pour un One Node est ron_<nom_du_serveur ou est crée la base>

	4 : Si la base est créée en 'Policy Managed' le pool 'poolAllNodes' sera crée
	    si -serverPollName n'est pas précisé.

	5 : Active le flag -policyManaged

	[-skip_db_create] à utiliser si la base est crées pour exécuter uniquement
	les scripts post installations.
"

script_banner $ME $*

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
			paramsql=param${db}.sql
			shift
			;;

		-pdbName=*)
			pdbName=${1##*=}
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
			skip_db_create=yes
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			rm -f $PLELIB_LOG_FILE
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

typeset		usefs=no

typeset -r redoLogFileSizeMb=128

#	============================================================================

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
			test_if_serverpool_exists $serverPoolName
			[ $? -ne 0 ] && add_dynamic_cmd_param "    -createServerPool"
			add_dynamic_cmd_param "    -serverPoolName $serverPoolName"
		fi
	fi

	add_dynamic_cmd_param "-gdbName $db"
	add_dynamic_cmd_param "-characterSet AL32UTF8"
	if [ "$usefs" = "no" ]
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
		if [ "$pdbName" != undef ]
		then
			add_dynamic_cmd_param "    -numberOfPDBs     $numberOfPDBs"
			add_dynamic_cmd_param "    -pdbName          $pdbName"
			add_dynamic_cmd_param "    -pdbAdminPassword $pdbAdminPassword"
		fi
	else
		add_dynamic_cmd_param "-createAsContainerDatabase false"
	fi
	add_dynamic_cmd_param "-sysPassword    $sysPassword"
	add_dynamic_cmd_param "-systemPassword $sysPassword"
	add_dynamic_cmd_param "-redoLogFileSize $redoLogFileSizeMb"

	add_dynamic_cmd_param "-totalMemory $totalMemory"
	if [[ "$shm_for_db" != "0" && $totalMemory -gt $(to_mb $shm_for_db) ]]
	then
		warning "totalMemoy (${totalMemory}M) > shm_for_db ($shm_for_db)"
	fi

	#	Ne jamais positionner pga_aggregate_limit en production.
	typeset initParams="-initParams threaded_execution=true,pga_aggregate_limit=1256M"
	case $lang in
		french)
			initParams="$initParams,nls_language=FRENCH,NLS_TERRITORY=FRANCE"
			;;
	esac
	if [ $shared_pool_size == default ]
	then
		initParams="$initParams,shared_pool_size=256M"
	else
		[ $shared_pool_size != "0" ] && initParams="$initParams,shared_pool_size=$shared_pool_size"
	fi
	add_dynamic_cmd_param "$initParams"
}

#	Return 0 if server pool $1 exists, else 1
function test_if_serverpool_exists
{
	typeset -r serverPoolName=$1

	info "Test if server pool $serverPoolName exists :"
	exec_cmd -ci "srvctl status srvpool -serverpool $serverPoolName"
	res=$?
	LN
	return $res
}

function remove_all_log_and_db_fs_files
{
	line_separator
	info "Remove all files on $(hostname -s)"
	if [ "$usefs" == "yes" ]
	then
		# Marche pas avec -i sed (oracle donc) n'a pas le droit de créer
		# de fichier temporaire dans /etc
		exec_cmd "sed '/^${db}.*/d' /etc/oratab > /tmp/oratab"
		exec_cmd "cat /tmp/oratab > /etc/oratab"

		exec_cmd rm -rf "$data/$db"
		exec_cmd rm -rf "$fra/$db"
		[ ! -d $data ] && exec_cmd mkdir -p $data
		[ ! -d $fra ] && exec_cmd mkdir -p $fra
	fi

	exec_cmd -c "rm -rf $ORACLE_BASE/cfgtoollogs/dbca/${db}*"
	exec_cmd -c "rm -rf $ORACLE_BASE/diag/rdbms/$lower_db"
	exec_cmd -c "rm -rf $ORACLE_BASE/admin/${db}"
	LN
}

#	Test si l'installation est de type RAC ou SINGLE.
#	Se base sur olsnodes.
#	Initialise les variables :
#		- node_list pour un RAC contiendra tous les nœuds ou undef.
#		- db_type à SINGLE ou RAC
function check_rac_or_single
{
	test_if_cmd_exists olsnodes
	if [ $? -eq 0 ]
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
			count_nodes=count_nodes+1
		done<<<"$(olsnodes)"

		[ $db_type == undef ] && [ $count_nodes -gt 1 ] && db_type=RAC
	fi

	[ $db_type == undef ] && db_type=SINGLE

	#	Note sur un single olsnodes existe mais ne retourne rien.
	[ x"$node_list" == x ] && node_list=undef
}

#	Si db_type == SINGLE test si utilisation d'ASM ou fs
#	Si fs ajuste les variables data & fra.
function check_if_ASM_used
{
	if [ $db_type == SINGLE ]
	then
		test_if_cmd_exists olsnodes
		if [ $? -eq 0 ]
		then	# Si le GI est installé alors utilisation de ASM
			usefs=no
		else	# Pas de GI alors on est sur FS
			usefs=yes
			if [[ "$data" == DATA && "$fra" == FRA ]]
			then
				data=/$GRID_DISK/app/oracle/oradata/data
				fra=/$GRID_DISK/app/oracle/oradata/fra
			fi
		fi
	fi
}

#	Création de la base.
#	Ne rends pas la main sur une erreur.
function create_database
{
	remove_all_log_and_db_fs_files

	make_dbca_args

	exec_dynamic_cmd $confirm -ci dbca
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

#	Création des services pour les pdb.
#	TODO : Pour le moment service minimum
function create_services_for_pdb
{
	line_separator
	info "Create service for pdb $pdbName"
	case $db_type in
		RAC)
			if [ $serverPoolName == "undef" ]
			then
				exec_cmd "~/plescripts/db/create_srv_for_rac_db.sh -db=$db -pdbName=$pdbName -prefixService=pdb${pdbName}"
				LN
			else
				exec_cmd "~/plescripts/db/create_srv_for_rac_db.sh -db=$db -pdbName=$pdbName -prefixService=pdb${pdbName} -poolName=$serverPoolName"
				LN
			fi
			;;

		RACONENODE)
			info "Create service for RAC One Node"
			exec_cmd srvctl add service -db $db -service pdb$pdbName -pdb $pdbName
			exec_cmd srvctl start service -db $db -service pdb$pdbName
			exec_cmd "~/plescripts/db/add_tns_alias.sh -service_name=pdb$pdbName -host_name=$(hostname -s)"
			LN
			;;

		SINGLE)
			if [ $usefs == no ]
			then
				info "Create service for SINGLE database."
				exec_cmd "~/plescripts/db/create_srv_for_single_db.sh -db=$db -pdbName=$pdbName"
				LN
			else
				warning "No services created for pdb, DIY"
			fi
			;;
	esac
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
	line_separator
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
				exec_cmd scp $node:~/plescripts/oracle_preinstall/glogin.sql $ORACLE_HOME/sqlplus/admin/glogin.sql
				LN
			fi
		done
	fi

	exec_cmd cp ~/plescripts/oracle_preinstall/glogin.sql $ORACLE_HOME/sqlplus/admin/glogin.sql
	LN
}

#	============================================================================
#	MAIN
#	============================================================================
script_start

check_rac_or_single
check_if_ASM_used

exit_if_param_undef		db							"$str_usage"
exit_if_param_invalid	enable_flashback "yes no"	"$str_usage"

#	----------------------------------------------------------------------------
#	Ajustement des paramètres
#	Détermine le nom de la PDB si non précisée.
[ $cdb == yes ] && [ $pdbName == undef ] && pdbName=${lower_db}01
[ $pdbName == no ] && pdbName=undef

if [ $pdbName != undef ]
then
	numberOfPDBs=1
	pdbAdminPassword=$sysPassword
fi

#	Si Policy Managed création du pool 'poolAllNodes' si aucun pool de précisé.
[ $policyManaged == "yes" ] && [ $serverPoolName == undef ] && serverPoolName=poolAllNodes
[ $serverPoolName != undef ] && policyManaged=yes
#	----------------------------------------------------------------------------

stats_tt start create_$lower_db

typeset prefixInstance=${db:0:8}

remove_glogin

[ $skip_db_create == no ] && create_database

[ "${db_type:0:3}" == "RAC" ] && update_rac_oratab

[ $cdb == yes ] && [ $pdbName != undef ] && create_services_for_pdb

if [ $usefs == yes ]
then
	line_separator
	info "Enable auto start for database"
	exec_cmd "sed \"s/^\(${db:0:8}.*\):N/\1:Y/\" /etc/oratab > /tmp/ot"
	exec_cmd "cat /tmp/ot > /etc/oratab"
	exec_cmd "rm /tmp/ot"
	LN

	if [ $pdbName != undef ]
	then
		line_separator
		warning "pdb $pdbName not open on startup, DIY."
		line_separator
		LN
	fi

	copy_glogin

	exit 0	#	Pour les base sur FS le reste du script est incompatible.
fi

line_separator
export ORACLE_DB=${db}
unset ORACLE_SID
fake_exec_cmd 'ORACLE_SID=$(ps -ef |  grep [p]mon | grep -vE "MGMTDB|ASM" | cut -d_ -f3-4)'
ORACLE_SID=$(ps -ef |  grep [p]mon | grep -vE "MGMTDB|ASM" | cut -d_ -f3-4)
info "Load env for $ORACLE_SID"
if [ x"$ORACLE_SID" == x ]
then
	error "ORACLE_SID not defined."
	exit 1
fi
ORAENV_ASK=NO . oraenv
LN

line_separator
info "Ajust FRA size"
sqlplus_cmd "$(set_sql_cmd "@$HOME/plescripts/db/sql/adjust_recovery_size.sql")"
LN

line_separator
info "Enable archivelog :"
info "Instance : $ORACLE_SID"
exec_cmd "~/plescripts/db/enable_archive_log.sh"
LN

if [ $enable_flashback == yes ]
then
	line_separator
	info "Enable flashback :"
	sqlplus_cmd "$(set_sql_cmd "alter database flashback on;")"
	LN
fi

line_separator
info "Database config :"
exec_cmd "srvctl config database -db $lower_db"
LN
line_separator
exec_cmd "crsctl stat res ora.$lower_db.db -t"
LN

copy_glogin

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

line_separator
exec_cmd "~/plescripts/memory/show_pages.sh"
LN

stats_tt stop create_$lower_db

script_stop $ME
LN
