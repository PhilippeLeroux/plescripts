#!/bin/bash

# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

#	12c ajustement :
#	Avec une shared_pool_size plus petite dbca risque de planter à 58%
#	min_memory_mb est le minimum pour la valeur de min_shared_pool_size_mb choisie
#	C'est probablement liée à la faible quantité de RAM.
#	TODO Rendre optionnel le paramétrage de la shared_pool_size
typeset -ri	min_memory_mb=444
typeset -ri	min_shared_pool_size_mb=256

typeset		name=undef
#typeset		db=undef
typeset		sysPassword=$oracle_password
typeset -i	memory_mb=$min_memory_mb
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

typeset		skip_db_create=no

typeset -r str_usage=\
"Usage : $ME
	-name=$name db name for single or db for RAC
	[-lang=$lang]
	[-sysPassword=$sysPassword]
	[-memory_mb=$memory_mb]
	[-cdb=$cdb]	(yes/no)	(1)
	[-pdbName=<str>]	(2)
	[-data=$data]
	[-fra=$fra]
	[-templateName=$templateName]
	[-db_type=SINGLE|RAC|RACONENODE]	(3)
	[-policyManaged]  : créer une base en 'Policy Managed'	(4)
	[-serverPoolName=<str> : nom du pool à utiliser, s'il n'existe pas il sera créée.

	1 : Si vaut yes et que -pdbName n'est pas précisé alors pdbName == name || 01
	    Le service de la pdb sera : pdb || name || 01

	2 : Si -pdbName est précisé -cdb vaut automatiquement yes

	3 : Si db_type n'est pas préciser il sera déterminer en fonction du nombre
	    de noeuds, si 1 seul noeud c'est SINGLE sinon c'est RAC.
	    Donc pour créer un RAC One Node database il faut impérativement le préciser !

	4 : Si la base est créée en 'Policy Managed' le pool 'poolAllNodes' sera crée
	    si -serverPollName n'est pas précisé.

	[-skip_db_create] à utiliser si la base est crées pour exécuter uniquement
	les scripts post installations.
"

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-name=*)
			name=$(to_upper ${1##*=})
			lower_name=$(to_lower $name)
			paramsql=param${name}.sql
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

		-memory_mb=*)
			memory_mb=${1##*=}
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

#	============================================================================
#	Test si l'installation est de type RAC ou SINGLE.
#	Se base sur olsnodes.
function is_rac_or_single_server
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
	[ x"$node_list" = x ] && node_list=undef
}

function make_dbca_args
{
	add_dynamic_cmd_param "-createDatabase -silent"

	add_dynamic_cmd_param "-databaseConfType $db_type"
	[ $db_type == RACONENODE ] && add_dynamic_cmd_param "    -RACOneNodeServiceName ron_$(to_lower $name)"

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

	add_dynamic_cmd_param "-gdbName $name"
	add_dynamic_cmd_param "-totalMemory $memory_mb"
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
	add_dynamic_cmd_param "-redoLogFileSize 512"
	case $lang in
		french)
			add_dynamic_cmd_param "-initParams shared_pool_size=${min_shared_pool_size_mb}M,nls_language=FRENCH,NLS_TERRITORY=FRANCE,threaded_execution=true"
			;;

		*)
			add_dynamic_cmd_param "-initParams shared_pool_size=${min_shared_pool_size_mb}M,threaded_execution=true"
	esac
}

#	Return 0 if server pool $1 exists, else 1
function test_if_serverpool_exists
{
	typeset -r serverPoolName=$1

	info "Server pool $serverPoolName exists :"
	exec_cmd -ci "srvctl status srvpool -serverpool $serverPoolName"
}

function remove_all_log_and_db_fs_files
{
	line_separator
	info "Remove all files on $(hostname -s)"
	if [ "$usefs" = "yes" ]
	then
		# Marche pas avec -i sed (oracle donc) n'a pas le droit de créer
		# de fichier temporaire dans /etc
		exec_cmd "sed '/^${name}.*/d' /etc/oratab > /tmp/oratab"
		exec_cmd "cat /tmp/oratab > /etc/oratab"

		exec_cmd rm -rf "$data/$name"
		exec_cmd rm -rf "$fra/$name"
		[ ! -d $data ] && exec_cmd mkdir $data
		[ ! -d $fra ] && exec_cmd mkdir $fra
	fi

	typeset -r dbca_log_path="$ORACLE_BASE/cfgtoollogs/dbca/*"
	exec_cmd -c "rm -rf $dbca_log_path"
	exec_cmd -c "rm -rf $ORACLE_BASE/diag/rdbms/$(to_lower $name)"
	LN
}

function on_ctrl_c
{
	LN
	info "${BLINK}ctrl-c from user.${NORM}"
	show_cursor
	exit 1
}

#	============================================================================
#	MAIN
#	============================================================================
typeset -r script_start_at=$SECONDS

is_rac_or_single_server
if [ $db_type == SINGLE ]
then
	test_if_cmd_exists olsnodes
	if [ $? -eq 0 ]
	then	# Si le GI est installé alors utilisation de ASM
		usefs=no
	else	# Pas de GI alors on est sur FS
		usefs=yes
		if [[ $data == DATA && $fra == FRA ]]
		then
			data=/u01/app/oracle/oradata/data
			fra=/u01/app/oracle/oradata/fra
		fi
	fi
fi

exit_if_param_undef name "$str_usage"

#===============================================================================
#	Ajustement des paramètres

#	Détermine le nom de la PDB si non précisée.
[ $cdb == yes ] && [ $pdbName == undef ] && pdbName=${lower_name}01

if [ $pdbName != undef ]
then
	numberOfPDBs=1
	pdbAdminPassword=$sysPassword
fi

#	Si Policy Managed création du pool 'poolAllNodes' si aucun pool de précisé.
[ $policyManaged == "yes" ] && [ $serverPoolName == undef ] && serverPoolName=poolAllNodes

if [ $memory_mb -lt $min_memory_mb ]
then
	error "Minimum memory for Oracle Database 12c : ${min_memory_mb}Mb"
	exit 1
fi
#===============================================================================

if [ $skip_db_create == no ]
then
	remove_all_log_and_db_fs_files

	make_dbca_args

	exec_dynamic_cmd -confirm -ci dbca
	typeset -ri	dbca_return=$?
	if [ $dbca_return -eq 0 ]
	then
		info "dbca [$OK]"
		LN
	else
		info "dbca [$KO] return $dbca_return"
		exit 1
	fi
fi	#	skip_db_create == no

typeset prefixInstance=${name:0:8}

if [ "${db_type:0:3}" == "RAC" ]
then
	[ $policyManaged == "yes" ] || [ $db_type == "RACONENODE" ] && prefixInstance=${prefixInstance}_

	for node in $( sed "s/,/ /g" <<<"$node_list" )
	do
		line_separator
		exec_cmd "ssh -t oracle@${node} \". ./.profile; ~/plescripts/db/update_rac_oratab.sh -db=$lower_name -prefixInstance=$prefixInstance\""
		LN
	done
fi

if [ $cdb == yes ] && [ x"$pdbName" != x ]
then
	line_separator
	info "Create service for pdb $pdbName"
	case $db_type in
		RAC)
			if [ $serverPoolName == "undef" ]
			then
				# Lecture des noms de toutes les instances.
				typeset inst_list
				while IFS=':' read inst_name rem
				do
					[ x"$inst_list" = x ] && inst_list=$inst_name || inst_list=${inst_list}",$inst_name"
				done<<<"$(cat /etc/oratab | grep "^${prefixInstance}[1-9]:")"

				info "Create service for RAC Administrator Managed"
				exec_cmd "srvctl add service -db $name -service pdb$pdbName -pdb $pdbName -preferred \"$inst_list\""
			else
				info "Create service for RAC Policy Managed"
				exec_cmd "srvctl add service -db $name -service pdb$pdbName -pdb $pdbName -serverpool $serverPoolName"
			fi
			exec_cmd srvctl start service -db $name -service pdb$pdbName
			LN
			;;

		RACONENODE)
			info "Create service for RAC One Node"
			exec_cmd srvctl add service -db $name -service pdb$pdbName -pdb $pdbName
			exec_cmd srvctl start service -db $name -service pdb$pdbName
			LN
			;;

		SINGLE)
			if [ $usefs == no ]
			then
				info "Create service for SINGLE database."
				exec_cmd srvctl add service -db $name -service pdb$pdbName -pdb $pdbName
				exec_cmd srvctl start service -db $name -service pdb$pdbName
				LN
			fi
			;;
	esac
fi

line_separator
info "Enable archivelog :"
export ORACLE_DB=${name}
case $db_type in
	RAC|RACONENODE)
		ORACLE_SID=${prefixInstance}1
		;;

	SINGLE)
		ORACLE_SID=${prefixInstance}
		;;
esac
ORAENV_ASK=NO . oraenv

info "Instance : $ORACLE_SID"
exec_cmd "~/plescripts/db/enable_archive_log.sh"
LN

if [ $usefs == no ]
then
	line_separator
	info "Database config :"
	exec_cmd "srvctl config database -db $lower_name"
	LN
	line_separator
	exec_cmd "crsctl stat res ora.$lower_name.db -t"
	LN
else
	line_separator
	info "Enable auto start for database"
	exec_cmd "sed \"s/^\(${name:0:8}.*\):N/\1:Y/\" /etc/oratab > /tmp/ot"
	exec_cmd "cat /tmp/ot > /etc/oratab"
	exec_cmd "rm /tmp/ot"
	LN

	if [ $pdbName != undef ]
	then
		line_separator
		warning "pdb $pdbName not open on startup, do the task yourself."
		line_separator
		LN
	fi
fi

info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
LN
