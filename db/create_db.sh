#!/bin/bash

#	ts=4 sw=4

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
typeset		usefs=no
typeset		cdb=yes
typeset		lang=french
typeset		pdbName=undef
typeset		serverPoolName=undef
typeset		policyManaged=no

typeset		skip_db_create=no
typeset		graph=no

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

	[-graph] génération de logs sur l'évolution de la mémoire cf memplots.
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
				echo "Le fichier template '$templateName' n'existe pas."
				echo "Liste des templates disponibles : "
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

		-graph)
			graph=yes
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

#	============================================================================
typeset -r LOG_DBCA=${PLELIB_LOG_FILE}_dbca

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

function show_db_settings
{
	info "Create DB              : $name"
	info "lang                   : $lang"
	info "Type                   : $db_type"
	[ "$node_list" != undef ] && info "Nodes                  : $node_list"
	info "sys & system passwords : $sysPassword"
	info "memory                 : $(fmt_number $memory_mb)Mb $mem_suffix"
	if [ "$usefs" = "no" ]
	then
		info "dg data                : $data"
		info "dg fra                 : $fra"
	else
		info "fs data                : $data"
		info "fs fra                 : $fra"
	fi
	info "template               : $templateName"
	info "container database     : $cdb"
	if [ $pdbName != undef ]
	then
		numberOfPDBs=1
		pdbAdminPassword=$sysPassword
		info "   numberOfPDBs     : $numberOfPDBs"
		info "   pdbName          : $pdbName"
		info "   pdbAdminPassword : $pdbAdminPassword"
	fi
	if [ "$serverPoolName" != undef ]
	then
		info "policyManaged"
		info "	serverPoolName : ${serverPoolName}"
	fi
	LN

	if [ $skip_db_create == yes ]
	then
		warning "La base ne sera pas créée, elle doit donc exister."
		LN
	fi
}

#	Ajoute le paramètre $1 à la liste de paramètres pour dbca
#		2 variables sont utilisées
#		- fake_dbca_args utilisée pour l'affichage : formatage visuel
#		- dbca_args  qui contiendra les arguments pour dbca.
function add_dbca_param
{
	if [ x"$fake_dbca_args" = x ]
	then
		fake_dbca_args=$(printf "    %-55s" "$1")
		dbca_args="$1"
	else
		fake_dbca_args=$fake_dbca_args$(printf "\\\\\n    %-55s" "$1")
		dbca_args="$dbca_args $1"
	fi
}

#	Return 0 if server pool $1 exists, else 1
function test_if_serverpool_exists
{
	typeset -r serverPoolName=$1

	info "Test si le pool de serveurs $serverPoolName exists :"
	exec_cmd -ci "srvctl status srvpool -serverpool $serverPoolName"
}

#	Fabrique les arguments à passer à dbca en fonction des variables
#	globales.
#		2 variables sont utilisées
#		- fake_dbca_args utilisée pour l'affichage : formatage visuel
#		- dbca_args  qui contiendra les arguments pour dbca.
function make_dbca_args
{
	add_dbca_param "-createDatabase -silent"

	add_dbca_param "-databaseConfType $db_type"
	[ $db_type == RACONENODE ] && add_dbca_param "    -RACOneNodeServiceName ron_$(to_lower $name)"

	[ "$node_list" != undef ] && add_dbca_param "-nodelist $node_list"

	if [ $serverPoolName != undef ]
	then
		add_dbca_param "-policyManaged"
		if [ $cdb == yes ]
		then
			test_if_serverpool_exists $serverPoolName
			[ $? -ne 0 ] && add_dbca_param "    -createServerPool"
			add_dbca_param "    -serverPoolName $serverPoolName"
		fi
	fi

	add_dbca_param "-gdbName $name"
	add_dbca_param "-totalMemory $memory_mb"
	add_dbca_param "-characterSet AL32UTF8"
	if [ "$usefs" = "no" ]
	then
		add_dbca_param "-storageType ASM"
		add_dbca_param "    -diskGroupName     $data"
		add_dbca_param "    -recoveryGroupName $fra"
	else
		add_dbca_param "-datafileDestination     $data"
		add_dbca_param "-recoveryAreaDestination $fra"
	fi
	add_dbca_param "-templateName $templateName"
	if [ "$cdb" = yes ]
	then
		add_dbca_param "-createAsContainerDatabase true"
		if [ "$pdbName" != undef ]
		then
			add_dbca_param "    -numberOfPDBs     $numberOfPDBs"
			add_dbca_param "    -pdbName          $pdbName"
			add_dbca_param "    -pdbAdminPassword $pdbAdminPassword"
		fi
	else
		add_dbca_param "-createAsContainerDatabase false"
	fi
	add_dbca_param "-sysPassword    $sysPassword"
	add_dbca_param "-systemPassword $sysPassword"
	add_dbca_param "-redoLogFileSize 512"
	case $lang in
		french)
			add_dbca_param "-initParams shared_pool_size=${min_shared_pool_size_mb}M,nls_language=FRENCH,NLS_TERRITORY=FRANCE,threaded_execution=true"
			;;

		*)
			add_dbca_param "-initParams shared_pool_size=${min_shared_pool_size_mb}M,threaded_execution=true"
	esac
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

################################################################################
# Fonctions techniques/utilitaire
function launch_memstat
{
	exec_cmd -c -h "nohup ~/plescripts/memory/memstats.sh -title=create_db >/dev/null 2>&1 &"
	if [ $node_list != undef ]
	then
		while read node_name
		do
			if [ $node_name != $(hostname -s) ]
			then
				exec_cmd -h -c "ssh -n ${node_name} \
				\"nohup ~/plescripts/memory/memstats.sh -title=create_db >/dev/null 2>&1 &\""
			fi
		done<<<"$(olsnodes)"
	fi
}

function stop_memstat
{
	if [ "$DEBUG_PLE" = yes ]
	then
		exec_cmd -c "~/plescripts/memory/memstats.sh -title=create_db -kill"
	else
		exec_cmd -c -h "~/plescripts/memory/memstats.sh -title=create_db -kill" >/dev/null 2>&1
	fi

	if [ $node_list != undef ]
	then
		while read node_name
		do
			if [ $node_name != $(hostname -s) ]
			then
				if [ "$DEBUG_PLE" = yes ]
				then
					exec_cmd -c "ssh ${node_name} \
					\"~/plescripts/memory/memstats.sh -title=create_db -kill\""
				else
					exec_cmd -c -h "ssh ${node_name} \
					\"~/plescripts/memory/memstats.sh -title=create_db -kill\"" >/dev/null 2>&1
				fi
			fi
		done<<<"$(olsnodes)"
	fi
}

function stop_all_background_processes
{
	[ "$DEBUG_PLE" = yes ] && line_separator && info "cleanup :"

	[ $graph == yes ] && stop_memstat || true

	[ "$DEBUG_PLE" = yes ] && LN
}

function on_ctrl_c
{
	LN
	info "${BLINK}ctrl-c from user.${NORM}"
	show_cursor
	exit 1
}
################################################################################

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
		if [[ $data = DATA && $fra = FRA ]]
		then
			data=/u01/app/oracle/oradata/data
			fra=/u01/app/oracle/oradata/fra
		fi
	fi
fi

exit_if_param_undef name "$str_usage"

#	Détermine le nom de la PDB si non précisée.
[ $cdb == yes ] && [ $pdbName == undef ] && pdbName=${lower_name}01

#	Si Policy Managed création du pool 'poolAllNodes' si aucun pool de précisé.
[ $policyManaged == "yes" ] && [ $serverPoolName == undef ] && serverPoolName=poolAllNodes

show_db_settings

if [ $memory_mb -lt $min_memory_mb ]
then
	error "Minimum memory for Oracle Database 12c : ${min_memory_mb}Mb"
	exit 1
fi

info "Press a key to continue."
read keyboard

trap stop_all_background_processes EXIT
trap on_ctrl_c INT

if [ $skip_db_create == no ]
then
	[ $graph == yes ] && launch_memstat

	make_dbca_args

	chrono_start # mesure le temps d'exécution de dbca.

	remove_all_log_and_db_fs_files

	fake_exec_cmd "dbca\\\\\n$fake_dbca_args"
	if [ $? -eq 0 ]
	then
		#	Lance dbca en tâche de fond.
		dbca $dbca_args
		dbca_return=$?
	fi
	LN

	[ $dbca_return -eq 0 ] && dbca_status="[$OK]" || dbca_status="[$KO] return $dbca_return"
	info "dbca $dbca_status ${BOLD}$(fmt_seconds $(chrono_stop -q))"
	LN

	[ $dbca_return -ne 0 ] && exit 1 || true
fi	#	skip_db_create == no

typeset prefixInstance=${name:0:8}

if [ "${db_type:0:3}" == "RAC" ]
then
	[ $policyManaged == "yes" ] || [ $db_type == "RACONENODE" ] && prefixInstance=${prefixInstance}_

	for node in $( sed "s/,/ /g" <<<"$node_list" )
	do
		line_separator
		exec_cmd "ssh -t oracle@${node} \". ./.profile; ~/plescripts/db/update_rac_oratab.sh -db=$lower_name -prefixInstance=$prefixInstance\""
	done
fi

if [ $cdb == yes ] && [ x"$pdbName" != x ]
then
	line_separator
	info "Création du service pour le pdb $pdbName"
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

				info "Création du service pour un 'RAC Administrator Managed'"
				exec_cmd "srvctl add service -db $name -service pdb$pdbName -pdb $pdbName -preferred \"$inst_list\""
			else
				info "Création du service pour un 'RAC Policy Managed'"
				exec_cmd "srvctl add service -db $name -service pdb$pdbName -pdb $pdbName -serverpool $serverPoolName"
			fi
			exec_cmd srvctl start service -db $name -service pdb$pdbName
			LN
			;;

		RACONENODE)
			info "Création du service pour un 'RAC One Node'"
			exec_cmd srvctl add service -db $name -service pdb$pdbName -pdb $pdbName
			exec_cmd srvctl start service -db $name -service pdb$pdbName
			LN
			;;

		SINGLE)
			info "Création du service pour une base 'SINGLE'"
			exec_cmd srvctl add service -db $name -service pdb$pdbName -pdb $pdbName
			exec_cmd srvctl start service -db $name -service pdb$pdbName
			LN
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
	info "Active le démarrage/arrêt automatique de la base."
	exec_cmd "sed \"s/^\(${name}.*\):N/\1:Y/\" /etc/oratab > /tmp/ot"
	exec_cmd "cat /tmp/ot > /etc/oratab"
	exec_cmd "rm /tmp/ot"
	LN
fi

info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
LN
