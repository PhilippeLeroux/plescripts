#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC
#PAUSE=ON

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	[-primary=name]    Nom de la base primaire, par défaut lie \$ORACLE_SID
	-standby=name      Nom de la base standby (sera créée)
	-standby_host=name Nom du serveur ou résidera la standby

	Le script doit être exécuté sur la base primaire.
	Pour reconstruire une base suite à un faileover utiliser -skip_setup_primary

	Ordre des actions :
		setup_primary : configuration de la base primaire.
			-skip_setup_primary par exemple après un failover et qu'il faut
			refaire une base.

		setup_network : configuration des tns et listeners des 2 serveurs.
			-skip_setup_network passe cette étape.

		duplicate     : duplication de la base primaire.
			-skip_duplicate passe cette étape.

		finalyze_standby_config : finalise la configuration de la standby
			-skip_finalyze_standby_config passe cette étape.

		configure_and_enable_broker : configure et démarre le broker.
			-skip_configure_and_enable_broker passe cette étape.
"

info "Running : $ME $*"

typeset primary=undef
typeset standby=undef
typeset standby_host=undef

typeset skip_setup_primary=no
typeset skip_setup_network=no
typeset skip_duplicate=no
typeset	skip_finalyze_standby_config=no
typeset	skip_configure_and_enable_broker=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-primary=*)
			primary=$(to_upper ${1##*=})
			shift
			;;

		-standby=*)
			standby=$(to_upper ${1##*=})
			shift
			;;

		-standby_host=*)
			standby_host=${1##*=}
			shift
			;;

		-skip_setup_primary)
			skip_setup_primary=yes
			shift
			;;

		-skip_setup_network)
			skip_setup_network=yes
			shift
			;;

		-skip_duplicate)
			skip_duplicate=yes
			shift
			;;

		-skip_finalyze_standby_config)
			skip_finalyze_standby_config=yes
			shift
			;;

		-skip_configure_and_enable_broker)
			skip_configure_and_enable_broker=yes
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

[ $primary == undef ] && primary=ORACLE_SID
exit_if_param_undef primary			"$str_usage"
exit_if_param_undef standby			"$str_usage"
exit_if_param_undef standby_host	"$str_usage"

function run_sqlplus_on_standby
{
	fake_exec_cmd sqlplus -s sys/$oracle_password@${standby} as sysdba
	printf "set echo off\nset timin on\n$@\n" | sqlplus -s sys/$oracle_password@${standby} as sysdba
	LN
}

function get_primary_cfg
{
	to_exec "alter system set standby_file_management='AUTO' scope=both sid='*';"

	to_exec "alter system set log_archive_config='dg_config=($primary,$standby)' scope=both sid='*';"

	to_exec "alter system set fal_server='$standby' scope=both sid='*';"

	to_exec "alter system set log_archive_dest_1='location=use_db_recovery_file_dest valid_for=(all_logfiles,all_roles) db_unique_name=$primary' scope=both sid='*';"

	to_exec "alter system set log_archive_dest_2='service=$standby async valid_for=(online_logfiles,primary_role) db_unique_name=$standby' scope=both sid='*';"

	# Nécessaire si on détruit et refait la dataguard.
	to_exec "alter system set log_archive_dest_state_2='enable' scope=both sid='*';"

	echo prompt
	echo prompt --	Paramètres nécessitant un arrêt/démarrage :
	to_exec "alter system set remote_login_passwordfile='EXCLUSIVE' scope=spfile sid='*';"

	#to_exec "alter system set db_file_name_convert='+DATA/$standby/','+DATA/$primary/','+FRA/$standby/','+FRA/$primary/' scope=spfile sid='*';"

	#to_exec "alter system set log_file_name_convert='+DATA/$standby/','+DATA/$primary/','+FRA/$standby/','+FRA/$primary/' scope=spfile sid='*';"

	to_exec "alter database force logging;"

	to_exec "shutdown immediate"
	to_exec "startup"
}

function create_standby_redo_logs
{
	typeset -ri nr=$1
	typeset -r	redo_size_mb="$2"

	for i in $( seq $nr )
	do
		to_exec "alter database add standby logfile thread 1 size $redo_size_mb;"
	done
}

#	$1	nom du servue
#	$2	nom de l'hôte
#
#	Créé un alias ayant pour nom $2
function get_alias_for
{
	typeset	-r	service_name=$1
	typeset	-r	host_name=$2
cat<<EOA
$service_name =
	(DESCRIPTION =
		(ADDRESS =
			(PROTOCOL = TCP)
			(HOST = $host_name)
			(PORT = 1521)
		)
		(CONNECT_DATA =
			(SERVER = DEDICATED)
			(SERVICE_NAME = $service_name)
		)
	)
EOA
}

function get_alias_for_primary
{
	get_alias_for $primary $primary_host
}

function get_alias_for_standby
{
	get_alias_for $standby $standby_host
}

function get_primary_sid_list_listener_for
{
	typeset	-r	g_dbname=$1
	typeset -r	sid_name=$2
	typeset	-r	orcl_home="$3"

cat<<EOL

#	Added by bibi
SID_LIST_LISTENER =
	(SID_LIST =
		(SID_DESC =
			(GLOBAL_DBNAME = $g_dbname)
			(ORACLE_HOME = $orcl_home)
			(SID_NAME = $sid_name)
		)
  )
#	End bibi
EOL
}

function primary_listener_add_static_entry
{
	typeset -r primary_sid_list=$(get_primary_sid_list_listener_for $primary $primary "$ORACLE_HOME")
	info "Ajout d'un entrée statique dans le listener de la primaire."
	info "Sur une SINGLE GLOBAL_DBNAME == SID_NAME"

typeset -r script=/tmp/setup_listener.sh
cat<<EOS > $script
#!/bin/bash

grep -q SID_LIST_LISTENER \$TNS_ADMIN/listener.ora
if [ \$? -eq 0 ]
then
	echo "listener déjà configuré."
	exit 0
fi

echo "Configuration :"
cp \$TNS_ADMIN/listener.ora \$TNS_ADMIN/listener.ora.bibi.backup
echo "$primary_sid_list" >> \$TNS_ADMIN/listener.ora
lsnrctl reload
EOS
	exec_cmd "chmod ug=rwx $script"
	exec_cmd "sudo -u grid -i $script"
	LN
}

function standby_listener_add_static_entry
{
	typeset -r standby_sid_list=$(get_primary_sid_list_listener_for $standby $standby "$ORACLE_HOME")
	info "Ajout d'un entrée statique dans le listener de la standby."
	info "Sur une SINGLE GLOBAL_DBNAME == SID_NAME"
typeset -r script=/tmp/setup_listener.sh
cat<<EOS > $script
#!/bin/bash

grep -q SID_LIST_LISTENER \$TNS_ADMIN/listener.ora
if [ \$? -eq 0 ]
then
	echo "listener déjà configuré."
	exit 0
fi

echo "Configuration :"
cp \$TNS_ADMIN/listener.ora \$TNS_ADMIN/listener.ora.bibi.backup
echo "$standby_sid_list" >> \$TNS_ADMIN/listener.ora
lsnrctl reload
EOS
	exec_cmd chmod ug=rwx $script
	exec_cmd "scp $script $standby_host:$script"
	exec_cmd "ssh -t $standby_host sudo -u grid -i $script"
	LN
}

function add_standby_redolog
{
	info "Add stdby redo log"
	typeset		redo_size_mb=undef
	typeset	-i	nr_redo=-1
	read redo_size_mb nr_redo <<<"$(result_of_query "select distinct round(bytes/1024/1024)||'M', count(*) from v\$log group by bytes;" | tail -1)"
	info "La base possède $nr_redo redos de $redo_size_mb"

	typeset -ri nr_stdby_redo=nr_redo+1
	info " --> Ajout de $nr_stdby_redo standby redos de $redo_size_mb (Nombre à vérifier je ne suis pas certain...)"
	run_sqlplus "$(create_standby_redo_logs $nr_stdby_redo $redo_size_mb)"
	LN

	exec_query "set lines 130 pages 45\ncol member for a45\nselect * from v\$logfile order by type, group#;"
	LN
}

function setup_tnsnames
{
	exec_cmd "rm -f $tnsnames_file"
	if [ ! -f $tnsnames_file ]
	then
		info "Create file $tnsnames_file"
		info "Add alias $primary"
		get_alias_for_primary > $tnsnames_file
		echo " " >> $tnsnames_file
		info "Add alias $standby"
		get_alias_for_standby >> $tnsnames_file
		LN
		info "Copy tnsname.ora from $primary_host to $standby_host"
		exec_cmd "scp $tnsnames_file $standby_host:$tnsnames_file"
		LN
	else
		error "L'existence du fichier tnsnames.ora n'est pas encore prise en compte."
		exit 1
	fi
}

function start_standby
{
	info "Copie du fichier password."
	exec_cmd scp $ORACLE_HOME/dbs/orapw${primary} ${standby_host}:$ORACLE_HOME/dbs/orapw${standby}
	LN

	line_separator
	info "Création du répertoire $ORACLE_BASE/$standby/adump sur $standy_host"
	exec_cmd -c "ssh $standby_host mkdir -p $ORACLE_BASE/admin/$standby/adump"
	LN

	line_separator
	info "Configure et démarre $standby sur $standby_host (configuration minimaliste.)"
	ssh -t -t $standby_host<<EOS
	rm -f $ORACLE_HOME/dbs/sp*${standby}* $ORACLE_HOME/dbs/init*${standby}*
	echo "db_name='$standby'" > $ORACLE_HOME/dbs/init${standby}.ora
	export ORACLE_SID=$standby
	\sqlplus sys/Oracle12 as sysdba<<XXX
	startup nomount
	XXX
	exit
EOS
}

function run_duplicate
{
	info "Lance la duplication..."
	cat<<EOR >/tmp/duplicate.rman
	run {
		allocate channel prmy1 type disk;
		allocate channel prmy2 type disk;
		allocate auxiliary channel stby1 type disk;
		allocate auxiliary channel stby2 type disk;
		duplicate target database for standby from active database
		spfile
			parameter_value_convert '$primary','$standby'
			set db_unique_name='$standby'
			set db_create_file_dest='+DATA'
			set db_recovery_file_dest='+FRA'
			set control_files='+DATA','+FRA'
			set cluster_database='false'
			set fal_server='$primary'
			set standby_file_management='AUTO'
			set log_archive_config='dg_config=($primary,$standby)'
			set log_archive_dest_1='location=USE_DB_RECOVERY_FILE_DEST valid_for=(all_logfiles,all_roles) db_unique_name=$standby'
			set log_archive_dest_state_1='enable'
			set log_Archive_dest_2='service=$primary async noaffirm reopen=15 valid_for=(all_logfiles,primary_role) db_unique_name=$primary'
			set log_archive_dest_state_2='enable'
			nofilenamecheck
		 ;
	}
EOR

	exec_cmd "rman target sys/$oracle_password@$primary auxiliary sys/$oracle_password@$standby @/tmp/duplicate.rman"
}

function setup_primary
{
	line_separator
	info "Setup primary database $primary"
	run_sqlplus "$(get_primary_cfg)"
	LN

	line_separator
	add_standby_redolog
}

function setup_network
{
	line_separator
	setup_tnsnames

	line_separator
	primary_listener_add_static_entry

	line_separator
	standby_listener_add_static_entry
}

function duplicate
{
	line_separator
	start_standby

	line_separator
	run_duplicate

if [ 0 -eq 1 ]; then
	line_separator
	info "Il faut redémarrer la base pour prendre en compte log_archive_dest_2 (bug ?)"
	exec_cmd "srvctl stop database -db $primary"
	exec_cmd "srvctl start database -db $primary"
fi
	LN
}

function cmd_setup_broker_for_database
{
	typeset -r db=$1

	to_exec "alter system set dg_broker_start=false scope=both sid='*';"
	to_exec "alter system reset dg_broker_config_file1 scope=spfile sid='*';"
	to_exec "alter system reset dg_broker_config_file2 scope=spfile sid='*';"

	to_exec "alter system set dg_broker_config_file1 = '+DATA/$db/dr1db_$db.dat' scope=both sid='*';"
	to_exec "alter system set dg_broker_config_file2 = '+DATA/$db/dr2db_$db.dat' scope=both sid='*';"

	to_exec "alter system set dg_broker_start=true scope=both sid='*';"
}

function finalyze_standby_config
{
	line_separator
	info "Démarre la synchro."
	#	alter database recover managed standby database using current logfile disconnect;
	#	est deprecated. Voir alert.log après exécution.
	run_sqlplus_on_standby "$(to_exec "alter database recover managed standby database disconnect;")"
	LN

#	run_sqlplus "alter system switch logfile;\nalter system switch logfile;\nalter system switch logfile;"
#	LN

#	test_pause "Vérifier la synchro !"
#info -n "Temporisation "; pause_in_secs 10; LN

	line_separator
	info "Enregistre la base dans le GI."
	exec_cmd "ssh -t oracle@$standby_host \". .profile; srvctl add database \
		-db $standby \
		-oraclehome $ORACLE_HOME \
		-spfile $ORACLE_HOME/dbs/spfile${standby}.ora \
		-role physical_standby \
		-dbname $primary \
		-diskgroup DATA,FRA \
		-verbose\""
	LN

	info "Arrêt/démarrage pour que le GI prenne en compte la base"
	run_sqlplus_on_standby "$(to_exec "shutdown immediate;")"
	exec_cmd "ssh -t oracle@$standby_host \". .profile; srvctl start database -db $standby\""
	LN
}

function configure_and_enable_broker
{
	line_separator
	info "Configuration du broker sur les bases :"
	info "  Sur la primaire $primary"
	run_sqlplus "$(cmd_setup_broker_for_database $primary)"
	LN
	info "  Sur la standby $standby"
	run_sqlplus_on_standby "$(cmd_setup_broker_for_database $standby)"
	LN

	line_separator
	info "Activation du broker"
	run_sqlplus "$(to_exec "alter system set log_Archive_dest_2='';")"
	run_sqlplus_on_standby "$(to_exec "alter system set log_Archive_dest_2='';")"
	LN

	info -n "Temporisation : "; pause_in_secs 30; LN

	dgmgrl<<EOS
	connect sys/$oracle_password
	create configuration 'PRODCONF' as primary database is $primary connect identifier is $primary;
	add database $standby as connect identifier is $standby maintained as physical;
	enable configuration;
EOS
	info "dgmgrl return code = $?"
	LN
}

function drop_all_services
{
	line_separator
	exec_cmd ~/plescripts/db/drop_all_services.sh -db=$primary
}

function create_stby_service
{
typeset -r query=\
"select
	c.name
from
	gv\$containers c
	inner join gv\$instance i
		on  c.inst_id = i.inst_id
	where
		i.instance_name = '$primary'
	and	c.name not in ( 'PDB\$SEED', 'CDB\$ROOT' );
"
	#	Les services existant ne somt pas valables pour un dataguard.
	drop_all_services

	line_separator
	while read pdbName
	do
		[ x"$pdbName" == x ] && continue

		info "Create stby service for pdb $pdbName on cdb $primary"
		exec_cmd "~/plescripts/db/create_service_for_standalone_dataguard.sh \
				-db=$primary -pdbName=$pdbName \
				-prefixService=pdb${pdbName} -role=primary"

		info "Les services pour le role standby sur démarrés pour contourner un bug."
		exec_cmd "~/plescripts/db/create_service_for_standalone_dataguard.sh \
				-db=$primary -pdbName=$pdbName \
				 -prefixService=pdb${pdbName}_stby -role=physical_standby"

		info "Mainenant ils sont stoppés, toujours pour l'histoire du bug."
		exec_cmd "srvctl stop service -service pdb${pdbName}_stby_oci -db $primary"
		exec_cmd "srvctl stop service -service pdb${pdbName}_stby_java -db $primary"
		LN

		info "Create services for pdb $pdbName on cdb $standby"
		info "BUG : il faut démarrer/arrêter les service standby et la primaire"
		info "      sinon le démarrage des services standby échoue."
		exec_cmd "ssh -t -t $standby_host '. .profile; \
				~/plescripts/db/create_service_for_standalone_dataguard.sh \
				-db=$standby -pdbName=$pdbName \
				-prefixService=pdb${pdbName}_stby -role=physical_standby'"

		exec_cmd "ssh -t -t $standby_host '. .profile; \
				~/plescripts/db/create_service_for_standalone_dataguard.sh \
				-db=$standby -pdbName=$pdbName \
				-prefixService=pdb${pdbName} -role=primary -start=no'"
		LN
	done<<<"$(result_of_query "$query")"
}

typeset	-r	primary_host=$(hostname -s)
typeset	-r	tnsnames_file=$TNS_ADMIN/tnsnames.ora

chrono_start

info "Create dataguard :"
info "	- from database $primary on $primary_host"
info "	- with database $standby on $standby_host"
LN

line_separator
info -n "Try to join $standby_host : "
ping -c 1 $standby_host >/dev/null 2>&1
if [ $? -eq 0 ]
then
	info -f "[$OK]"
	LN
else
	info -f "[$KO]"
	exit 1
fi

line_separator
info "Load env for $primary"
ORACLE_SID=$primary
ORAENV_ASK=NO . oraenv
LN

[ $skip_setup_primary == no ] && setup_primary

[ $skip_setup_network == no ] && setup_network

[ $skip_duplicate == no ] && duplicate && test_pause "duplicate terminé."

[ $skip_finalyze_standby_config == no ] && finalyze_standby_config

[ $skip_configure_and_enable_broker == no ] && configure_and_enable_broker

create_stby_service

chrono_stop $ME
