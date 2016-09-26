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
		setup_network : configuration des tns et listeners des 2 serveurs.
			-skip_setup_network passe cette étape.

		setup_primary : configuration de la base primaire.
			-skip_setup_primary passe cette étape.

		duplicate     : duplication de la base primaire.
			-skip_duplicate passe cette étape.

		register_standby_to_GI : finalise la configuration de la standby
			-skip_register_standby_to_GI passe cette étape.

		create_dataguard_services : crée les services.
			-skip_create_dataguard_services passe cette étape

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
typeset	skip_register_standby_to_GI=no
typeset	skip_create_dataguard_services=no
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

		-skip_register_standby_to_GI)
			skip_register_standby_to_GI=yes
			shift
			;;

		-skip_create_dataguard_services)
			skip_create_dataguard_services=yes
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

#	Contiendra la listes des services à démarrer sur la stby après la création
#	du broker.
#	Les noms des services seront séparés par un espace.
typeset stby_services_to_start

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

#	return YES flashback enable
#	return NO flashback disable
function read_flashback_value
{
typeset -r query=\
"select
    flashback_on
from
    v\$database
;"

	sqlplus_exec_query "$query" | tail -1
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
#	L'entrée *_DGMGRL peut être évitée mais il faut modifier les propriètés du dgmgrl
SID_LIST_LISTENER=
	(SID_LIST=
		(SID_DESC=
			(SID_NAME=$sid_name)
			(GLOBAL_DBNAME=${g_dbname}_DGMGRL)
			(ORACLE_HOME=$orcl_home)
			(ENVS="TNS_ADMIN=$orcl_home/network/admin")
		)
		(SID_DESC=
			(SID_NAME=$sid_name)
			(GLOBAL_DBNAME=${g_dbname})
			(ORACLE_HOME=$orcl_home)
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
	info "Add static listeners on $primary_host : "
	info "On SINGLE GLOBAL_DBNAME == SID_NAME"

typeset -r script=/tmp/setup_listener.sh
cat<<EOS > $script
#!/bin/bash

grep -q SID_LIST_LISTENER \$TNS_ADMIN/listener.ora
if [ \$? -eq 0 ]
then
	echo "Already configured."
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
	info "Add static listeners on $standby_host : "
	info "On SINGLE GLOBAL_DBNAME == SID_NAME"
typeset -r script=/tmp/setup_listener.sh
cat<<EOS > $script
#!/bin/bash

grep -q SID_LIST_LISTENER \$TNS_ADMIN/listener.ora
if [ \$? -eq 0 ]
then
	echo "Already configured."
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
	info "$primary : $nr_redo redo logs of $redo_size_mb"
	info " --> Add $nr_stdby_redo SRLs of $redo_size_mb"
	sqlplus_cmd "$(sqlcmd_create_standby_redo_logs $nr_stdby_redo $redo_size_mb)"
	LN

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
	info "Run duplicate :"
cat<<EOR >/tmp/duplicate.rman
run {
	allocate channel prim1 type disk;
	allocate channel prim2 type disk;
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

#	Fabrique les commandes permettant :
#		- de configurer un dataguard
#		- faire le duplicate
#	Toutes les commandes sont fabriquées avec la fonction to_exec.
#	Passer la sortie de cette fonction en paramètre de la fonction sqlplus_cmd
function sqlcmd_primary_cfg
{
	to_exec "alter system set standby_file_management='AUTO' scope=both sid='*';"

	to_exec "alter system set log_archive_config='dg_config=($primary,$standby)' scope=both sid='*';"

	to_exec "alter system set fal_server='$standby' scope=both sid='*';"

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

#	Efface la configuration du broker.
function remove_broker_cfg
{
	line_separator
	info "Remove broker configuration."
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
	info "Setup primary database $primary for duplicate & dataguard."
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

	to_exec "alter system set dg_broker_config_file1 = '+DATA/$db/dr1db_$db.dat' scope=both sid='*';"
	to_exec "alter system set dg_broker_config_file2 = '+FRA/$db/dr2db_$db.dat' scope=both sid='*';"

	to_exec "alter system set dg_broker_start=true scope=both sid='*';"
}

function sqlcmd_mount_db_and_start_recover
{
	to_exec "shutdown immediate;"
	to_exec "startup mount;"
	to_exec "recover managed standby database disconnect;"
}

#	Après que la duplication ait été faite finalise la configuration.
#	Actions :
#		- backup de l'alertlog de la standby (pour ne plus avoir 50K de messages d'erreurs)
#		- démarre la synchro
#		- enregistre la standby dans le GI.
function register_standby_to_GI
{
	line_separator
	info "Backup standby alertlog :"
	typeset -r alert_log="$ORACLE_BASE/diag/rdbms/$(to_lower $standby)/$standby/trace/alert_${standby}.log"
	exec_cmd "ssh oracle@$standby_host '. .profile; mv $alert_log ${alert_log}.after_duplicate'"
	LN

	line_separator
	info "GI : register standby database on $standby_host :"
	exec_cmd "ssh -t oracle@$standby_host \". .profile; srvctl add database \
		-db $standby \
		-oraclehome $ORACLE_HOME \
		-spfile $ORACLE_HOME/dbs/spfile${standby}.ora \
		-role physical_standby \
		-dbname $primary \
		-diskgroup DATA,FRA \
		-verbose\""
	LN

	info "$standby : mount & start recover :"
	sqlplus_cmd_on_standby "$(sqlcmd_mount_db_and_start_recover)"
	timing 10 "Wait recover"
}

#	Création de la configuration du dataguard et démarrage du broker.
function create_dataguard_cfg
{
	line_separator
	info "Dataguard configuration."
	sqlplus_cmd "$(to_exec "alter system set log_Archive_dest_2='' scope=both sid='*';")"
	LN

	timing 5

	dgmgrl -silent -echo sys/$oracle_password<<EOS | tee -a $PLELIB_LOG_FILE
create configuration 'DGCONF' as primary database is $primary connect identifier is $primary;
add database $standby as connect identifier is $standby maintained as physical;
enable configuration;
EOS
	LN

	timing 10 "Waiting recover"
}

#	Configure et démarre le broker dataguard.
#	Actions :
#		- Configuration des 2 bases
#		- Configuration de la dataguard et démarrage du broker.
function configure_and_enable_broker
{
	line_separator
	if [ $skip_primary_cfg == no ]
	then
		info "Configure broker on primary $primary"
		sqlplus_cmd "$(sqlcmd_setup_broker_for_database $primary)"
		LN
	fi

	info "Configure broker on standby $standby"
	sqlplus_cmd_on_standby "$(sqlcmd_setup_broker_for_database $standby)"
	info "Open read only $standby for Real Time Query"
	sqlplus_cmd_on_standby "$(to_exec "alter database open read only;")"
	LN

	create_dataguard_cfg
	LN

	line_separator
	if [ $skip_primary_cfg == no ]
	then
		info "Workaround bug : drc${primary}.log show errors with broker files."
		sqlplus_cmd "$(to_exec "alter system set dg_broker_start=false sid='*';")"
		sqlplus_cmd "$(sqlcmd_setup_broker_for_database $primary)"
		LN
	fi

	info "Workaround bug : drc${standby}.log show errors with broker files."
	sqlplus_cmd_on_standby "$(to_exec "alter system set dg_broker_start=false sid='*';")"
	sqlplus_cmd_on_standby "$(sqlcmd_setup_broker_for_database $standby)"
	LN

	timing 5 "Synchro broker"
}

#	Supprime tous les services de la primaire.
function drop_all_services_on_primary
{
	exec_cmd $ROOT/db/drop_all_services.sh -db=$primary
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

	if [ $skip_primary_cfg == no ]
	then
		#	Les services existant ne sont pas valables pour un dataguard.
		drop_all_services_on_primary
	fi

	line_separator
	while read pdbName
	do
		[ x"$pdbName" == x ] && continue

		if [ $skip_primary_cfg == no ]
		then
			info "Create stby service for pdb $pdbName on cdb $primary"
			exec_cmd "$ROOT/db/create_srv_for_single_db.sh \
					-db=$primary -pdbName=$pdbName \
					-role=primary"
			LN

			exec_cmd "$ROOT/db/create_srv_for_single_db.sh \
					-db=$primary -pdbName=$pdbName \
					-role=physical_standby"
			LN
		fi

		info "Create services for pdb $pdbName on cdb $standby"
		exec_cmd "ssh -t -t $standby_host '. .profile; \
				$ROOT/db/create_srv_for_single_db.sh \
				-db=$standby -pdbName=$pdbName \
				-role=primary -start=no'</dev/null"
		LN

		#	Ne pas démarrer les services stby sur la stdy sinon sa plante.
		#	Le faire après la création du broker.
		exec_cmd "ssh -t -t $standby_host '. .profile; \
				$ROOT/db/create_srv_for_single_db.sh \
				-db=$standby -pdbName=$pdbName \
				-role=physical_standby -start=no'</dev/null"
		stby_services_to_start="$stby_services_to_start pdb${pdbName}_stby_oci pdb${pdbName}_stby_java"
		LN

		info "Stop stby services on primary $primary :"
		exec_cmd "srvctl stop service -db $primary -service pdb${pdbName}_stby_oci"
		exec_cmd "srvctl stop service -db $primary -service pdb${pdbName}_stby_java"
		LN
	done<<<"$(sqlplus_exec_query "$query")"
}

function sqlcmd_enable_flashback
{
	to_exec "recover managed standby database cancel;"
	to_exec "alter database flashback on;"
	to_exec "recover managed standby database disconnect;"
}

typeset	-r	primary_host=$(hostname -s)
typeset	-r	tnsnames_file=$TNS_ADMIN/tnsnames.ora

script_start

info "Create dataguard :"
info "	- between database $primary on $primary_host"
info "	- and database $standby on $standby_host"
LN

exec_cmd -c "$ROOT/shell/test_ssh_equi.sh -user=oracle -server=$standby_host"
if [ $? -ne 0 ]
then
	line_separator
	info "From $client_hostname :"
	info "$ cd $ROOT/db/stby script"
	info "$ ./00_setup_equivalence.sh -user1=oracle -server1=$primary_host -server2=$standby_host"
	exit 1
fi
LN

[ $skip_setup_network == no ] && setup_network

[ $skip_setup_primary == no ] && setup_primary

[ $skip_duplicate == no ] && duplicate

[ $skip_register_standby_to_GI == no ] && register_standby_to_GI

[ $skip_create_dataguard_services == no ] && create_dataguard_services

[ $skip_configure_and_enable_broker == no ] && configure_and_enable_broker

if [ "$(read_flashback_value)" == YES ]
then
	line_separator
	info "Enable flashback on $standby"
	sqlplus_cmd_on_standby "$(sqlcmd_enable_flashback)"
fi

if [ x$"stby_services_to_start" != x ]
then
	line_separator
	info "Start stby services on $standby"
	for service in $stby_services_to_start
	do
		exec_cmd -c "ssh oracle@$standby_host '. .profile;		\
						srvctl start service	-db $standby	\
												-service $service</dev/null'"
		LN
		[ $? -ne 0 ] && warning "Start service $service later."
	done
fi

exec_cmd "$ROOT/db/stby/show_dataguard_cfg.sh"

script_stop $ME
