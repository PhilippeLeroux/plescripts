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
	-standby=name       Nom de la base standby (sera créée)
	-standby_host=name  Nom du serveur ou résidera la standby
	[-skip_primary_cfg] A utiliser lors de la recréation d'une standby après failover.

	Le script doit être exécuté sur la base primaire et l'envirronement de la base
	primaire chargé.

	Flags de debug :
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

typeset standby=undef
typeset standby_host=undef
typeset skip_primary_cfg=no

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

		-standby=*)
			standby=$(to_upper ${1##*=})
			shift
			;;

		-standby_host=*)
			standby_host=${1##*=}
			shift
			;;

		-skip_primary_cfg)
			skip_primary_cfg=yes
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

typeset -r primary=$ORACLE_SID
if [[ x"$primary" == x || "$primary" == NOSID ]]
then
	error "ORACLE_SID not defined."
	LN

	info "$str_usage"
	exit 1
fi

exit_if_param_undef standby			"$str_usage"
exit_if_param_undef standby_host	"$str_usage"

#	Exécute la commande "$@" avec sqlplus sur la standby
function sqlplus_cmd_on_standby
{
	fake_exec_cmd sqlplus -s sys/$oracle_password@${standby} as sysdba
	printf "${SPOOL}set echo off\nset timin on\n$@\n" |\
		 sqlplus -s sys/$oracle_password@${standby} as sysdba
	LN
}

#	Lie et affiche la valeur du paramètre remote_login_passwordfile
function read_remote_login_passwordfile
{
typeset -r query=\
"select
    value
from
    v\$parameter
where
    name = 'remote_login_passwordfile'
;"

	sqlplus_exec_query "$query" | tail -1
}

#	Fabrique l'ensemble des commandes permettant de configurer la base primaire.
#	Toutes les commandes sont fabriquées avec la fonction to_exec.
#	Passer la sortie de cette fonction en paramètre de la fonction sqlplus_cmd
function sqlcmd_primary_cfg
{
	to_exec "alter system set standby_file_management='AUTO' scope=both sid='*';"

	to_exec "alter system set log_archive_config='dg_config=($primary,$standby)' scope=both sid='*';"

	to_exec "alter system set fal_server='$standby' scope=both sid='*';"

	# Nécessaire tant que le broker n'est pas activé.
	to_exec "alter system set log_archive_dest_2='service=$standby async valid_for=(online_logfiles,primary_role) db_unique_name=$standby' scope=both sid='*';"

	# Nécessaire si on détruit et refait la dataguard.
	to_exec "alter system set log_archive_dest_state_2='enable' scope=both sid='*';"

	if [ $skip_primary_cfg == no ]
	then
		to_exec "alter database force logging;"

		if [ "$(read_remote_login_passwordfile)" != "EXCLUSIVE" ]
		then
			echo prompt
			echo prompt --	Paramètres nécessitant un arrêt/démarrage :
			to_exec "alter system set remote_login_passwordfile='EXCLUSIVE' scope=spfile sid='*';"

			to_exec "shutdown immediate"
			to_exec "startup"
		fi
	fi
}

#	Fabrique les commandes permettant de créer les SRLs
#	$1	nombre de SRLs à créer.
#	$2	taille des SRLs
#	Passer la sortie de cette fonction en paramètre de la fonction sqlplus_cmd
function sqlcmd_create_standby_redo_logs
{
	typeset -ri nr=$1
	typeset -r	redo_size_mb="$2"

	for i in $( seq $nr )
	do
		to_exec "alter database add standby logfile thread 1 size $redo_size_mb;"
	done
}

#	Affiche sur la sortie standard la configuration de l'alias TNS.
#	$1	service_name qui sera aussi le nom de l'alias.
#	$2	nom du serveur
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

#	Affiche sur la sortie standard la configuration d'un listener statique.
#	$1	GLOBAL_DBNAME
#	$2	SID_NAME
#	$3	ORACLE_HOME
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
			(ENVS="TNS_ADMIN=$orcl_home/network/admin")
		)
  )
#	End bibi
EOL
}

#	Ajoute une entrée statique au listener de la primaire.
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

#	Ajoute une entrée statique au listener de la secondaire.
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

function sqlcmd_print_redo
{
	to_exec "set lines 130 pages 45"
	to_exec "col member for a45"
	to_exec "select * from v\$logfile order by type, group#;"
}

#	Création des SRLs sur la base primaire.
function add_standby_redolog
{
	info "Add stdby redo log"

	typeset		redo_size_mb=undef
	typeset	-i	nr_redo=-1
	read redo_size_mb nr_redo <<<"$(sqlplus_exec_query "select distinct round(bytes/1024/1024)||'M', count(*) from v\$log group by bytes;" | tail -1)"

	typeset -ri nr_stdby_redo=nr_redo+1
	info "La base possède $nr_redo redos de $redo_size_mb"
	info " --> Ajout de $nr_stdby_redo standby redos de $redo_size_mb"
	sqlplus_cmd "$(sqlcmd_create_standby_redo_logs $nr_stdby_redo $redo_size_mb)"
	LN

	#sqlplus_print_query "set lines 130 pages 45\ncol member for a45\nselect * from v\$logfile order by type, group#;"
	sqlplus_print_query "$(sqlcmd_print_redo)"
	LN
}

#	Configure les fichiers tnsnames sur le serveur primaire et secondaire.
#	1	Sur le serveur primaire si le fichier existe, il est supprimé.
#	2	Sur le serveur secondaire le fichier est écrasé par celui du primaire.
function setup_tnsnames
{
	exec_cmd "rm -f $tnsnames_file"
	if [ ! -f $tnsnames_file ]
	then
		info "Create file $tnsnames_file"
		info "Add alias $primary"
		get_alias_for $primary $primary_host > $tnsnames_file
		echo " " >> $tnsnames_file
		info "Add alias $standby"
		get_alias_for $standby $standby_host >> $tnsnames_file
		LN
		info "Copy tnsname.ora from $primary_host to $standby_host"
		exec_cmd "scp $tnsnames_file $standby_host:$tnsnames_file"
		LN
	else
		error "L'existence du fichier tnsnames.ora n'est pas encore prise en compte."
		exit 1
	fi
}

#	Démarre une base standby minimum.
#	Actions :
#		- copie du fichier 'password' de la primaire vers la standby
#		- création du répertoire adump sur le serveur de la standby
#		- puis démarre la standby uniquement avec le paramètre db_name
function start_standby
{
	info "Copie du fichier password."
	exec_cmd scp $ORACLE_HOME/dbs/orapw${primary} ${standby_host}:$ORACLE_HOME/dbs/orapw${standby}
	LN

	line_separator
	info "Création du répertoire $ORACLE_BASE/$standby/adump sur $standby_host"
	exec_cmd -c "ssh $standby_host mkdir -p $ORACLE_BASE/admin/$standby/adump"
	LN

	line_separator
	info "Configure et démarre $standby sur $standby_host (configuration minimaliste.)"
ssh -t -t $standby_host<<EOS | tee -a $PLELIB_LOG_FILE
rm -f $ORACLE_HOME/dbs/sp*${standby}* $ORACLE_HOME/dbs/init*${standby}*
echo "db_name='$standby'" > $ORACLE_HOME/dbs/init${standby}.ora
export ORACLE_SID=$standby
\sqlplus -s sys/Oracle12 as sysdba<<XXX
startup nomount
XXX
exit
EOS
LN
}

#	Lance la duplication de la base avec RMAN
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
		set log_Archive_dest_2=''
		nofilenamecheck
	 ;
}
EOR
	exec_cmd "rman target sys/$oracle_password@$primary auxiliary sys/$oracle_password@$standby @/tmp/duplicate.rman"
}

#	Efface la configuration du broker.
function remove_broker_cfg
{
	line_separator
	info "Efface la configuration du broker."
dgmgrl -silent -echo<<EOS | tee -a $PLELIB_LOG_FILE
connect sys/$oracle_password
disable configuration;
remove configuration;
EOS
LN
LN
}

#	Applique l'ensemble des paramètres nécessaires pour une base primaire et pour
#	le duplicate RMAN.
function setup_primary
{
	if [ $skip_primary_cfg == no ]
	then
		line_separator
		add_standby_redolog
	else
		remove_broker_cfg
		LN
	fi

	line_separator
	info "Setup primary database $primary"
	sqlplus_cmd "$(sqlcmd_primary_cfg)"
	LN
}

#	Effectue la configuration réseau sur les 2 serveurs.
#	Configuration des fichiers tnsnames.ora et listener.ora
function setup_network
{
	line_separator
	setup_tnsnames

	line_separator
	primary_listener_add_static_entry

	line_separator
	standby_listener_add_static_entry
}

#	Effectue la duplication de la base.
#	Actions :
#		- démarre une standby minimum
#		- affiche des informations sur les 2 bases.
#		- lance la duplication via RMAN.
function duplicate
{
	line_separator
	start_standby

	line_separator
	info "Info :"
	exec_cmd "tnsping $primary | tail -3"
	LN
	exec_cmd "tnsping $standby | tail -3"
	LN

	line_separator
	run_duplicate
}

#	Configure le broker pour la base $1
function sqlcmd_setup_broker_for_database
{
	typeset -r db=$1

	to_exec "alter system set dg_broker_start=false scope=both sid='*';"

	to_exec "alter system set dg_broker_config_file1 = '+DATA/$db/dr1db_$db.dat' scope=both sid='*';"
	to_exec "alter system set dg_broker_config_file2 = '+DATA/$db/dr2db_$db.dat' scope=both sid='*';"

	to_exec "alter system set dg_broker_start=true scope=both sid='*';"
}

function sqlcmd_mount_and_start_recover
{
	to_exec "shutdown immediate;"
	to_exec "startup mount;"
	#	recover managed standby database using current logfile disconnect;
	#	est deprecated. Voir alert.log après exécution.
	to_exec "recover managed standby database disconnect;"
}

#	Après que la duplication ait été faite finalise la configuration.
#	Actions :
#		- backup de l'alertlog de la standby (pour ne plus avoir 50K de messages d'erreurs)
#		- démarre la synchro
#		- enregistre la standby dans le GI.
function finalyze_standby_config
{
	line_separator
	info "Backup le journal d'alerte de la standby."
	typeset -r alert_log="$ORACLE_BASE/diag/rdbms/$(to_lower $standby)/$standby/trace/alert_${standby}.log"
	exec_cmd "ssh oracle@$standby_host '. .profile; mv $alert_log ${alert_log}.after_duplicate'"
	LN

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
	sqlplus_cmd_on_standby "$(sqlcmd_mount_and_start_recover)"
	timing 10 "Wait recover"
}

#	Création de la configuration du dataguard et démarrage du broker.
function create_dataguard_cfg
{
	line_separator
	info "Configuration du dataguard."
	sqlplus_cmd "$(to_exec "alter system set log_Archive_dest_2='';")"
	LN

	timing 30

dgmgrl -silent -echo sys/$oracle_password<<EOS | tee -a $PLELIB_LOG_FILE
create configuration 'DGCONF' as primary database is $primary connect identifier is $primary;
add database $standby as connect identifier is $standby maintained as physical;
enable configuration;
EOS
	LN

	timing 25 "Waiting recover"
}

#	Configure et démarre le broker dataguard.
#	Actions :
#		- Configuration des 2 bases
#		- Configuration de la dataguard et démarrage du broker.
function configure_and_enable_broker
{
	line_separator
	info "Configuration du broker sur les bases :"
	if [ $skip_primary_cfg == no ]
	then
		info "  Sur la primaire $primary"
		sqlplus_cmd "$(sqlcmd_setup_broker_for_database $primary)"
		LN
	fi

	info "  Sur la standby $standby"
	sqlplus_cmd_on_standby "$(sqlcmd_setup_broker_for_database $standby)"
	LN

	create_dataguard_cfg
	LN
}

#	Supprime tous les services de la primaire.
function drop_all_services_on_primary
{
	exec_cmd ~/plescripts/db/drop_all_services.sh -db=$primary
}

#	Création des services :
#		-	2 services (oci et java) avec le role primary sur les 2 bases.
#		-	2 services (oci et java) avec le role standby sur les 2 bases.
#	Les services sont créés à partir du nom du PDB
#	TODO : tester avec plusieurs PDBs.
function create_dataguard_services
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

	line_separator
	while read pdbName
	do
		[ x"$pdbName" == x ] && continue

		if [ $skip_primary_cfg == no ]
		then
			#	Les services existant ne sont pas valables pour un dataguard.
			drop_all_services_on_primary

			info "Create stby service for pdb $pdbName on cdb $primary"
			exec_cmd "~/plescripts/db/create_service_for_standalone_dataguard.sh \
					-db=$primary -pdbName=$pdbName \
					-prefixService=pdb${pdbName} -role=primary"
			LN

			exec_cmd "~/plescripts/db/create_service_for_standalone_dataguard.sh \
					-db=$primary -pdbName=$pdbName \
					 -prefixService=pdb${pdbName}_stby -role=physical_standby"
			LN

			info "Il faut démarrer/arrêter les services standby et primaire"
			info "sinon le démarrage des services standby échoue sur la standby."
			exec_cmd "srvctl stop service -service pdb${pdbName}_stby_oci -db $primary"
			exec_cmd "srvctl stop service -service pdb${pdbName}_stby_java -db $primary"
			LN
		fi

		info "Open read only $standby"
		sqlplus_cmd_on_standby "$(to_exec "alter database open read only;")"
		LN
		exec_cmd "ssh -t -t $standby_host '. .profile;srvctl stop database -db $standby'"
		exec_cmd "ssh -t -t $standby_host '. .profile;srvctl start database -db $standby'"
		LN

		info "Create services for pdb $pdbName on cdb $standby"
		exec_cmd "ssh -t -t $standby_host '. .profile; \
				~/plescripts/db/create_service_for_standalone_dataguard.sh \
				-db=$standby -pdbName=$pdbName \
				-prefixService=pdb${pdbName} -role=primary -start=no'"
		LN

		exec_cmd "ssh -t -t $standby_host '. .profile; \
				~/plescripts/db/create_service_for_standalone_dataguard.sh \
				-db=$standby -pdbName=$pdbName \
				-prefixService=pdb${pdbName}_stby -role=physical_standby'"
		LN
	done<<<"$(sqlplus_exec_query "$query")"
}

typeset	-r	primary_host=$(hostname -s)
typeset	-r	tnsnames_file=$TNS_ADMIN/tnsnames.ora

script_start

info "Create dataguard :"
info "	- from database $primary on $primary_host"
info "	- with database $standby on $standby_host"
LN

exec_cmd -c "~/plescripts/shell/test_ssh_equi.sh -user=oracle -server=$standby_host"
if [ $? -ne 0 ]
then
	info "Exécuter depuis $client_hostname dans ~/plescripts/db/stby le script :"
	info "./00_setup_equivalence.sh -user1=oracle -server1=$primary_host -server2=$standby_host"
	exit 1
fi
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

[ $skip_setup_primary == no ] && setup_primary

[ $skip_setup_network == no ] && setup_network

[ $skip_duplicate == no ] && duplicate && test_pause "duplicate terminé."

[ $skip_finalyze_standby_config == no ] && finalyze_standby_config

[ $skip_configure_and_enable_broker == no ] && configure_and_enable_broker

create_dataguard_services

line_separator
exec_cmd "~/plescripts/db/stby/show_dataguard_cfg.sh"

script_stop $ME
