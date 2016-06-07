#!/bin/sh

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
typeset -ri min_shared_pool_size_mb=256

typeset name=undef
typeset db=undef
typeset sysPassword=$oracle_password
typeset -i memory_mb=$min_memory_mb
typeset data=DATA
typeset fra=FRA
typeset templateName=General_Purpose.dbc
typeset db_type=undef
typeset node_list=undef
typeset usefs=no
typeset cdc=yes
typeset lang=french
typeset verbose=no
typeset pdbName=undef
typeset serverPoolName=undef

typeset -r str_usage=\
"Usage :
$ME
	-name=$name db name for single or db for RAC
	-lang=$lang
	-sysPassword=$sysPassword
	-memory_mb=$memory_mb
	-cdc=$cdc	(yes/no)
	[-pdbName=<str>]
	-data=$data
	-fra=$fra
	-templateName=$templateName
	-db_type=SINGLE|RAC|RACONENODE (1)

	1 : Pour le RAC one node il faut impérativement le préciser !

	[-verbose]
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

		-cdc=*)
			cdc=$(to_lower ${1##*=})
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

		-verbose)
			verbose=yes
			shift
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
	db_type=SINGLE
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

		[ $count_nodes -gt 1 ] && db_type=RAC
	fi
	#	Note sur un single olsnodes existe mais ne fait rien
	[ x"$node_list" = x ] && node_list=undef
}

function launch_memstat
{
	exec_cmd -c "nohup ~/plescripts/memory/memstats.sh -title=create_db >/dev/null 2>&1 &"
	if [ $node_list != undef ]
	then
		while read node_name
		do
			if [ $node_name != $(hostname -s) ]
			then
				exec_cmd -c "ssh -n ${node_name} \
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
		exec_cmd -c "~/plescripts/memory/memstats.sh -title=create_db -kill" >/dev/null 2>&1
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
					exec_cmd -c "ssh ${node_name} \
					 \"~/plescripts/memory/memstats.sh -title=create_db -kill\"" >/dev/null 2>&1
				fi
			fi
		done<<<"$(olsnodes)"
	fi
}

function show_db_settings
{
	info "Create DB              : $name"
	info "lang                   : $lang"
	info "Type                   : $db_type"
	[ $node_list != undef ] && info "Nodes                  : $node_list"
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
	info "container database     : $cdc"
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
}

#   Ajoute le paramètre $1 à la liste de paramètres pour dbca
#       2 variables sont utilisées
#         - fake_dbca_args utilisée pour l'affichage : formatage visuel
#         - dbca_args  qui contiendra les arguments pour dbca.
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

#	Fabrique les arguments à passer à dbca en fonction des variables
#	globales.
#		2 variables sont utilisées
#			- fake_dbca_args utilisée pour l'affichage : formatage visuel
#			- dbca_args  qui contiendra les arguments pour dbca.
function make_dbca_args
{
	add_dbca_param "-createDatabase -silent"
	add_dbca_param "-databaseConfType $db_type"
	[ "$node_list" != undef ] && add_dbca_param "-nodelist $node_list"
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
	if [ "$cdc" = yes ]
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
	if [ "$serverPoolName" != undef ]
	then
		add_dbca_param "-policyManaged"
		add_dbca_param "	-serverPoolName ${serverPoolName}"
	fi
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

#	$1 max len
#	$2 string
#
#	Si la longueur de string est supérieur à max len alors
#	string est raccourcie pour ne faire que max len caractères.
#
#	Par exemple
#				XXXXXXXXXXXXXXXXXXX
#	deviendra	XXX...XXX
function shorten_string
{
	typeset -i	max_len=$1
	typeset -r	string=$2
	typeset -ri	string_len=${#string}

	if [ $string_len -gt $max_len ]
	then
		max_len=max_len-3 #-3 pour les ...
		typeset -ri	car_to_remove=$(compute -i "($string_len - $max_len)/2")
		typeset -ri begin_len=$(compute -i "$string_len / 2 - $car_to_remove")
		typeset -ri end_start=$(compute -i "$string_len - ( $string_len / 2 - $car_to_remove )" )
		comp="${string:0:$begin_len}...${string:$end_start}"
		echo "$comp"
	else
		echo $string
	fi
}

# $1 gap		(si non précisé vaudra 0)
# $2 string
function string_fit_on_screen
{
	typeset -i	gap=1
	typeset 	string="$1"
	if [ $# -eq 2 ]
	then
		gap=$1
		string="$2"
	fi

	typeset -i len=$(term_cols)
	len=len-gap

	shorten_string $len "$string"
}

#	Attend l'existence d'un fichier
function wait_file
{
	typeset -r	file_name="$1"
	typeset		tag="=-"
	typeset		file_exists=no
	typeset	-i	duration=0

	[ -f $file_name ] && return 0

	info $(string_fit_on_screen 4 "Wait until $file_name exists.")
	typeset -i begin_at=$SECONDS
	hide_cursor
	while [ $file_exists = no ] && [ $duration -lt 180 ]
	do
		typeset -i col=$(term_cols)
		typeset -i loops=col-2
		printf "["
		for i in $( seq 1 $loops )
		do
			echo -n $tag
			sleep 1
			printf "\b"
			[ -f $file_name ] && file_exists=yes && break
		done
		printf "]\n"
		duration=$(( SECONDS - begin_at ))
	done
	show_cursor

	[ $file_exists = yes ] && return 0 || return 1
}

# Arrête un process :
# $1 nom du process
# $2 nom de la variable contenant le pid
#	la variable sera mise à -1 si le process est stoppé.
function stop_process
{
	typeset pid_name=$1
	typeset pid_value=${!2}

	[ "$DEBUG_PLE" = yes ] && info -n "Stop process $pid_name "
	if [ $pid_value -ne -1 ]
	then
		kill -1 $pid_value >/dev/null 2>&1
		kill_return=$?
		if [ $kill_return -eq 0 ]
		then
			eval $2=-1
			[ "$DEBUG_PLE" = yes ] && info -f "[$OK]"
			return 0
		else
			[ "$DEBUG_PLE" = yes ] && info -f "[$KO]"
			return 1
		fi
	else
		[ "$DEBUG_PLE" = yes ] && info -f ": ${BOLD}not running.${NORM}"
	fi

	return 0
}

typeset -i pid_tail=-1
typeset -i pid_dbca=-1
function stop_all_background_processes
{
	[ "$DEBUG_PLE" = yes ] && line_separator && info "cleanup :"

	stop_process dbca pid_dbca

	stop_memstat

	stop_process log_process pid_tail

	[ "$DEBUG_PLE" = yes ] && LN
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
[ $db_type = undef ] && is_rac_or_single_server
if [ $db_type = SINGLE ]
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

show_db_settings

if [ $memory_mb -lt $min_memory_mb ]
then
	error "Minimum memory for Oracle Database 12c : ${min_memory_mb}Mb"
	exit 1
fi

exit_if_param_undef name "$str_usage"

info "Press a key to continue."
read keyboard

trap stop_all_background_processes EXIT
trap on_ctrl_c INT

launch_memstat

make_dbca_args

chrono_start

remove_all_log_and_db_fs_files

fake_exec_cmd "dbca\\\\\n$fake_dbca_args"
if [ $? -eq 0 ]
then
	#	Lance dbca en tâche de fond.
	dbca $dbca_args > ${LOG_DBCA} 2>&1 &
	pid_dbca=$!
fi
LN

if [ $verbose == yes ]
then
	[[ $db_type == RAC* ]] && noi=1
	alert_log=$ORACLE_BASE/diag/rdbms/$lower_name/${name}${noi}/trace/alert_${name}${noi}.log

	wait_file $alert_log
	if [ $? -ne 0 ]
	then
		info "Wait again."
		wait_file $alert_log
		[ $? -ne 0 ] && wait_file $alert_log
						[ $? -ne 0 ] && verbose=no
	fi

	if [ $verbose = yes ]
	then
		tail -1000f $alert_log | tee -a $PLELIB_LOG_FILE &
		pid_tail=$!
		pid_tail=pid_tail-1
	fi
fi

if [ $verbose = no ]
then
	wait_file $LOG_DBCA
	tail -1000f $LOG_DBCA | tee -a $PLELIB_LOG_FILE &
	pid_tail=$!
	pid_tail=pid_tail-1
fi

#	Attend la fin de dbca
wait $pid_dbca
dbca_return=$?
[ $dbca_return -eq 0 ] && dbca_status="[$OK]" || dbca_status="[$KO] return $dbca_return"
info "dbca $dbca_status ${BOLD}$(fmt_seconds $(chrono_stop -q))"
pid_dbca=-1
LN

stop_process log_process pid_tail

if [ $verbose = yes ]
then
	line_separator
	exec_cmd "cat $LOG_DBCA"
	LN
fi

exec_cmd "rm -f $LOG_DBCA"  >/dev/null 2>&1

if [ $dbca_return -ne 0 ]
then
	error "dbca failed."
	exit 1
fi
LN

[[ "$db_type" == "RAC*" ]] && line_separator && exec_cmd "./update_oratab.sh -db=$lower_name"

line_separator
info "Enable archivelog :"
[[ "$db_type" == "RAC*" ]] && ORACLE_SID=${name}1 || ORACLE_SID=${name}
ORAENV_ASK=NO . oraenv
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
fi
