#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/db/wallet/walletlib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC
#PAUSE=ON

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-standby=name             Nom de la base standby (sera créée)
	-standby_host=name        Nom du serveur ou résidera la standby
	[-create_primary_cfg=yes] Mettre 'no' si la configuration a déjà été faite.
	[-no_backup]              Ne pas faire de backup.

	Le script doit être exécuté sur le serveur de la base primaire et
	l'environnement de la base primaire doit être chargé.

	Flags de debug :
		setup_network : configuration des tns et listeners des 2 serveurs.
			-skip_setup_network passe cette étape.

		setup_primary : configuration de la base primaire.
			-skip_setup_primary passe cette étape.

		duplicate     : duplication de la base primaire.
			-skip_duplicate passe cette étape.

		register_stby_to_GI : finalise la configuration de la standby
			-skip_register_stby_to_GI passe cette étape.

		create_dataguard_services : crée les services.
			-skip_create_dataguard_services passe cette étape

		configure_dataguard : configure le broker et le dataguard.
			-skip_configure_dataguard passe cette étape.
"

typeset standby=undef
typeset standby_host=undef
typeset create_primary_cfg=yes
typeset	backup=yes

typeset _setup_primary=yes
typeset _setup_network=yes
typeset _duplicate=yes
typeset	_register_stby_to_GI=yes
typeset	_create_dataguard_services=yes
typeset	_configure_dataguard=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

		-no_backup)
			backup=no
			shift
			;;

		-create_primary_cfg=*)
			create_primary_cfg=$(to_lower ${1##*=})
			shift
			;;

		-skip_setup_primary)
			_setup_primary=no
			shift
			;;

		-skip_setup_network)
			_setup_network=no
			shift
			;;

		-skip_duplicate)
			_duplicate=no
			shift
			;;

		-skip_register_stby_to_GI)
			_register_stby_to_GI=no
			shift
			;;

		-skip_create_dataguard_services)
			_create_dataguard_services=no
			shift
			;;

		-skip_configure_dataguard)
			_configure_dataguard=no
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

ple_enable_log -params $PARAMS

exit_if_ORACLE_SID_not_defined
typeset -r primary=$ORACLE_SID

exit_if_param_undef standby			"$str_usage"
exit_if_param_undef standby_host	"$str_usage"

# Requête permettant de lire tous les PDBs existant sur la base $primary
typeset -r sql_read_pdbs=\
"select
	c.name
from
	gv\$containers c
	inner join gv\$instance i
		on  c.inst_id = i.inst_id
	where
		i.instance_name = '$primary'
	and	c.name not in ( 'PDB\$SEED', 'CDB\$ROOT', 'PDB_SAMPLES' );
"

# $1 account
# $@ command
#
# Load .bash_profile.
#
# Fonction peu utilisée car ajoutée tardivement.
function ssh_stby
{
	if [ "$1" == "-c" ]
	then
		typeset farg="-c"
		shift
	else
		typeset farg
	fi

	typeset -r ssh_account="$1"
	shift

	exec_cmd $farg "ssh -t -t $ssh_account@${standby_host} \". .bash_profile; $@\"</dev/null"
}

#	Exécute la commande "$@" avec sqlplus sur la standby
function sqlplus_cmd_on_stby
{
	sqlplus_cmd_with "sys/$oracle_password@${standby} as sysdba" "$@"
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
function sqlcmd_create_stby_redo_logs
{
	typeset -ri nr=$1
	typeset -r	redo_size_mb="$2"

	for (( i=0; i < nr; ++i ))
	do
		set_sql_cmd "alter database add standby logfile thread 1 size $redo_size_mb;"
	done
}

# Affiche sur stdout le db_unique_name à utiliser pour la Physical stby database.
function get_db_unique_name_for_stby
{
	typeset db_name=$(orcl_parameter_value db_name)
	typeset db_unique_name=$(orcl_parameter_value db_unique_name)

	if [ "$db_name" == "$db_unique_name" ]
	then # Base à l'origine du Dataguard
		echo "$standby"
	else # Base créée à partir de la Primary
		echo "$db_name"
	fi
}

#	Affiche sur la sortie standard la configuration d'un listener statique.
#	$1	GLOBAL_DBNAME
#	$2	GLOBAL_DBNAME for broker
#	$3	SID_NAME
#	$4	ORACLE_HOME
#
#	Remarque :
#	 - Il peut y avoir plusieurs SID_LIST_LISTENER, les configurations s'ajoutent.
#	 - TODO : la suppression d'un SID_LIST_LISTENER devrait être facilement faisable.
#		grep -n "# Added by bibi : $sid_name" pour la première ligne.
#		grep -n "End bibi : $sid_name" pour la dernière ligne.
function make_sid_list_listener_for
{
	typeset	-r	g_dbname=$1
	typeset	-r	g_dbname_dgmgrl=$2
	typeset -r	sid_name=$3
	typeset	-r	orcl_home="$4"

cat<<EOL

SID_LIST_LISTENER=	# Added by bibi : $sid_name
	(SID_LIST=
		(SID_DESC= # Peut être évité si les propriétés du dataguard sont modifiées.
			(SID_NAME=$sid_name)
			(GLOBAL_DBNAME=${g_dbname_dgmgrl}_DGMGRL)
			(ORACLE_HOME=$orcl_home)
			(ENVS="TNS_ADMIN=$orcl_home/network/admin")
		)
		(SID_DESC=
			(SID_NAME=$sid_name)
			(GLOBAL_DBNAME=${g_dbname})
			(ORACLE_HOME=$orcl_home)
			(ENVS="TNS_ADMIN=$orcl_home/network/admin")
		)
	) #	End bibi : $sid_name
EOL
}

#	Ajoute une entrée statique au listener de la primaire.
function primary_listener_add_static_entry
{
	typeset -r primary_sid_list=$(make_sid_list_listener_for $primary $primary $primary "$ORACLE_HOME")
	info "Add static listeners on $primary_host : "
	info "$primary_sid_list"
	LN

typeset -r script=/tmp/setup_listener.sh
cat<<EOS > $script
#!/bin/bash

grep -q "# Added by bibi : $primary" \$TNS_ADMIN/listener.ora
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
	if [ $crs_used == yes ]
	then
		exec_cmd "sudo -u grid -i $script"
	else
		exec_cmd "$script"
	fi
	LN
}

#	Ajoute une entrée statique au listener de la secondaire.
function stby_listener_add_static_entry
{
	typeset -r stby_db_unique_name="$(get_db_unique_name_for_stby)"
	typeset -r standby_sid_list=$(make_sid_list_listener_for $standby $stby_db_unique_name $standby "$ORACLE_HOME")
	info "Add static listeners on $standby_host : "
	info "$standby_sid_list"
	LN

typeset -r script=/tmp/setup_listener.sh
cat<<EOS > $script
#!/bin/bash

grep -q "# Added by bibi : $standby" \$TNS_ADMIN/listener.ora
if [ \$? -eq 0 ]
then
	echo "Already configured."
	exit 0
fi

echo "Configuration :"
cp \$TNS_ADMIN/listener.ora \$TNS_ADMIN/listener.ora.bibi.backup
echo "$standby_sid_list" >> \$TNS_ADMIN/listener.ora
lsnrctl stop
lsnrctl start
EOS

	exec_cmd chmod ug=rwx $script
	exec_cmd "scp $script $standby_host:$script"
	if [ $crs_used == yes ]
	then
		exec_cmd "ssh -t $standby_host sudo -u grid -i $script"
	else
		exec_cmd "ssh -t $standby_host '. .bash_profile && $script'"
	fi
	LN
}

function sql_print_redo
{
	set_sql_cmd "set lines 130 pages 45"
	set_sql_cmd "col member for a45"
	set_sql_cmd "select * from v\$logfile order by type, group#;"
}

#	Création des SRLs sur la base primaire.
function add_stby_redolog
{
	info "Add stdby redo log"

	typeset		redo_size_mb=undef
	typeset	-i	nr_redo=-1
	read redo_size_mb nr_redo <<<"$(sqlplus_exec_query "select distinct round(bytes/1024/1024)||'M', count(*) from v\$log group by bytes;" | tail -1)"

	typeset -ri nr_stdby_redo=nr_redo+1
	info "$primary : $nr_redo redo logs of $redo_size_mb"
	info " --> Add $nr_stdby_redo SRLs of $redo_size_mb"
	sqlplus_cmd "$(sqlcmd_create_stby_redo_logs $nr_stdby_redo $redo_size_mb)"
	LN

	sqlplus_print_query "$(sql_print_redo)"
	LN
}

#	Configure les fichiers tnsnames sur le serveur primaire et secondaire.
#	1	Sur le serveur primaire si le fichier existe, il est supprimé.
#	2	Sur le serveur secondaire le fichier est écrasé par celui du primaire.
#
#	Ajoute les alias pour les connexions sur les CDBs, pas les PDBs.
function setup_tnsnames
{
	line_separator
	exec_cmd "~/plescripts/db/add_tns_alias.sh	\
				-service=$primary				\
				-host_name=$primary_host"
	LN

	line_separator
	exec_cmd "~/plescripts/db/add_tns_alias.sh	\
				-service=$standby				\
				-host_name=$standby_host		\
				-copy_server_list=$standby_host"
	LN
}

#	Démarre une base standby minimum.
#	Actions :
#		- copie du fichier 'password' de la primaire vers la standby
#		- création du répertoire adump sur le serveur de la standby
#		- puis démarre la standby uniquement avec le paramètre db_name
function start_stby
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

	[ $crs_used == no ] && stdby_update_oratab Y || true

ssh -t -t $standby_host<<EO_SSH_STBY | tee -a $PLELIB_LOG_FILE
rm -f $ORACLE_HOME/dbs/sp*${standby}* $ORACLE_HOME/dbs/init*${standby}*
echo "db_name='$standby'" > $ORACLE_HOME/dbs/init${standby}.ora
export ORACLE_SID=$standby
\sqlplus -s sys/Oracle12 as sysdba<<EO_SQL_DBSTARTUP
whenever sqlerror exit 1;
startup nomount
EO_SQL_DBSTARTUP
exit \$?
EO_SSH_STBY

	info "startup nomount return $?"
	LN
}

#	Lance la duplication de la base avec RMAN
function run_duplicate
{
	typeset stby_db_unique_name="$(get_db_unique_name_for_stby)"
	# Sur la Primary et sur la Physical les db_name sont identiques.
	typeset db_name=$(orcl_parameter_value db_name)

	info "db_name stby        : $db_name"
	info "db_unique_name stby : $stby_db_unique_name"
	LN

	if [ $crs_used == no ]
	then
		info "Create directories on stby server $standby_host"
		exec_cmd "ssh $standby_host mkdir -p $data/$standby"
		exec_cmd "ssh $standby_host mkdir -p $fra/$standby"
		control_files="'$data/$standby/control01.ctl','$fra/$standby/control02.ctl'"
		LN
	else
		control_files="'$data','$fra'"
	fi

	info "Run duplicate :"
cat<<EOR >/tmp/duplicate.rman
run {
	allocate channel prim1 type disk;
	allocate channel prim2 type disk;
	allocate auxiliary channel stby1 type disk;
	allocate auxiliary channel stby2 type disk;
	duplicate target database for standby from active database
	using compressed backupset
	spfile
		parameter_value_convert '$primary','$standby'
		set db_name='$db_name' #Obligatoire en 12.2, sinon le duplicate échoue.
		set db_unique_name='$stby_db_unique_name'
		set db_create_file_dest='$data'
		set db_recovery_file_dest='$fra'
		set control_files=$control_files
		set cluster_database='false'
		nofilenamecheck
	;
}
EOR
	exec_cmd "rman	target sys/$oracle_password@$primary	\
					auxiliary sys/$oracle_password@$standby @/tmp/duplicate.rman"
}

#	Fabrique les commandes permettant de configurer un dataguard
#	EST INUTILE : log_archive_dest_2='service=$standby async valid_for=(online_logfiles,primary_role) db_unique_name=$standby'
function sql_setup_primary_database
{
	set_sql_cmd "alter system set standby_file_management='AUTO' scope=both sid='*';"

	set_sql_cmd "alter system set dg_broker_config_file1 = '$data/$primary/dr1db_$primary.dat' scope=both sid='*';"

	set_sql_cmd "alter system set dg_broker_config_file2 = '$fra/$primary/dr2db_$primary.dat' scope=both sid='*';"

	set_sql_cmd "alter system set dg_broker_start=true scope=both sid='*';"

	if [ $create_primary_cfg == yes ]
	then
		set_sql_cmd "alter database force logging;"

		if [ "$(read_remote_login_passwordfile)" != "EXCLUSIVE" ]
		then
			echo prompt
			echo prompt --	Paramètres nécessitant un arrêt/démarrage :
			set_sql_cmd "alter system set remote_login_passwordfile='EXCLUSIVE' scope=spfile sid='*';"

			set_sql_cmd "shutdown immediate"
			set_sql_cmd "startup"
		fi
	fi
}

#	Supprime la standby de la configuration du dataguard.
function remove_stby_database_from_dataguard_config
{
	line_separator
	info "Dataguard : remove standby $standby if exist."
	dgmgrl -silent -echo<<-EOS | tee -a $PLELIB_LOG_FILE
	connect sys/$oracle_password
	remove database $standby
	EOS
	LN
}

#	Applique l'ensemble des paramètres nécessaires pour une base primaire et pour
#	le duplicate RMAN.
function setup_primary
{
	if [ $create_primary_cfg == yes ]
	then
		line_separator
		add_stby_redolog

		line_separator
		info "Setup primary database $primary for duplicate & dataguard."
		sqlplus_cmd "$(sql_setup_primary_database)"
		LN

		info "Adjust rman config for dataguard."
		exec_cmd "rman target sys/$oracle_password \
			@$HOME/plescripts/db/rman/ajust_config_for_dataguard.rman"
		LN
	else
		remove_stby_database_from_dataguard_config
		LN
	fi
}

#	Effectue la configuration réseau sur les 2 serveurs.
#	Configuration des fichiers tnsnames.ora et listener.ora
function setup_network
{
	setup_tnsnames

	line_separator
	primary_listener_add_static_entry

	line_separator
	stby_listener_add_static_entry
}

#	Effectue la duplication de la base.
#	Actions :
#		- démarre une standby minimum
#		- affiche des informations sur les 2 bases.
#		- lance la duplication via RMAN.
function duplicate
{
	line_separator
	start_stby

	line_separator
	info "Info :"
	exec_cmd "tnsping $primary | tail -3"
	LN
	exec_cmd "tnsping $standby | tail -3"
	LN

	line_separator
	run_duplicate
	LN
}

function sql_mount_db_and_start_recover
{
	set_sql_cmd "shutdown immediate;"
	set_sql_cmd "startup mount;"
	set_sql_cmd "recover managed standby database disconnect;"
}

# $1 Y|N
# Ajoute la base $standby dans /etc/oratab si elle n'y est pas.
function stdby_update_oratab
{
	typeset -r autostartup="$1"
	line_separator
	ssh_stby -c oracle "grep -q '^$standby' /etc/oratab"
	if [ $? -ne 0 ]
	then
		LN
		ssh_stby oracle "echo \"$standby:\$ORACLE_HOME:$autostartup\" >> /etc/oratab"
		LN
	else
		LN
	fi
}

#	Après que la duplication ait été faite, finalise la configuration.
#	Actions :
#		- backup de l'alertlog de la standby (pour ne plus avoir 50K de messages d'erreurs)
#		- démarre la synchro
#		- enregistre la standby dans le GI.
function register_stby_to_GI
{
	line_separator
	info "Backup standby alertlog :"
	typeset -r alert_log="$ORACLE_BASE/diag/rdbms/$(to_lower $standby)/$standby/trace/alert_${standby}.log"
	exec_cmd "ssh $standby_host '. .profile; mv $alert_log ${alert_log}.after_duplicate'"
	LN

	line_separator
	info "GI : register standby database on $standby_host :"
	exec_cmd "ssh -t $standby_host \". .profile;					\
				srvctl add database									\
					-db $standby									\
					-oraclehome $ORACLE_HOME						\
					-spfile $ORACLE_HOME/dbs/spfile${standby}.ora	\
					-role physical_standby							\
					-dbname $primary								\
					-diskgroup DATA,FRA								\
					-verbose\""
	LN

	info "$standby : mount & start recover :"
	sqlplus_cmd_on_stby "$(sql_mount_db_and_start_recover)"
	timing 10 "Wait recover"
	LN

	#	Workaround 12cR2
	stdby_update_oratab N
}

function create_dataguard_config
{
	info "Create data guard configuration."
	timing 10 "Wait data guard broker"
	LN
	fake_exec_cmd "dgmgrl -silent -echo sys/$oracle_password"
	dgmgrl -silent -echo sys/$oracle_password<<-EOS | tee -a $PLELIB_LOG_FILE
	create configuration 'DGCONF' as primary database is $primary connect identifier is $primary;
	enable configuration;
	EOS
	LN
}

function add_stby_to_dataguard_config
{
	info "Add standby $standby to data guard configuration."
	dgmgrl -silent -echo sys/$oracle_password<<-EOS | tee -a $PLELIB_LOG_FILE
	add database $standby as connect identifier is $standby maintained as physical;
	enable database $standby;
	EOS
	LN
}

#	Configure et démarre le broker dataguard.
#	Actions :
#		- Configuration des 2 bases
#		- Configuration de la dataguard et démarrage du broker.
function configure_dataguard
{
	line_separator
	[ $create_primary_cfg == yes ] && create_dataguard_config || true

	add_stby_to_dataguard_config

	timing 10 "Waiting recover"
	LN

	# Remarque : si la base n'est pas en 'Real Time Query' relancer la base
	# pour que le 'temporary file' soit crée.
	function open_ro
	{
		set_sql_cmd "alter database open read only;"
		set_sql_cmd "alter pluggable database all open;"
	}
	info "Open read only $standby for Real Time Query"
	sqlplus_cmd_on_stby "$(open_ro)"
	LN
}

#	Création des services :
#		-	2 services (oci et java) avec le role primary sur les 2 bases.
#		-	2 services (oci et java) avec le role standby sur les 2 bases.
#	Les services sont créés à partir du nom du PDB
#	****************************************************************************
#	Attention :
#	le script db/create_pdb.sh utilise le script db/create_srv_for_dataguard.sh
#	****************************************************************************
function create_dataguard_services_no_crs
{
	# $1 pdb name
	# $2 service name
	function stop_service
	{
		set_sql_cmd "alter session set container=$1;"
		set_sql_cmd "exec dbms_service.stop_service( '$2' );"
	}

	# $1 pdb name
	# $2 service name
	function start_service
	{
		set_sql_cmd "alter session set container=$1;"
		set_sql_cmd "exec dbms_service.start_service( '$2' );"
	}

	typeset oci_stby_service
	typeset java_stby_service

	while read pdb
	do
		[ x"$pdb" == x ] && continue

		oci_stby_service=$(mk_oci_stby_service $pdb)
		java_stby_service=$(mk_java_stby_service $pdb)

		line_separator
		info "$primary[$pdb] : update services."
		exec_cmd "~/plescripts/db/create_srv_for_single_db.sh	\
							-db=$primary -pdb=$pdb				\
							-role=primary -start=yes"
		LN

		info "$primary[$pdb] : create standby services."
		exec_cmd "~/plescripts/db/create_srv_for_single_db.sh	\
							-db=$primary -pdb=$pdb				\
							-role=physical_standby -start=no"
		LN

		if [ -d $wallet_path ]
		then
			line_separator
			info "Standby $standby_host : wallet add sys for $pdb to wallet"
			ssh_stby oracle "~/plescripts/db/add_sysdba_credential_for_pdb.sh	\
														-db=$standby -pdb=$pdb"
			LN
		fi

	done<<<"$(sqlplus_exec_query "$sql_read_pdbs")"
}

#	Création des services :
#		-	2 services (oci et java) avec le role primary sur les 2 bases.
#		-	2 services (oci et java) avec le role standby sur les 2 bases.
#	Les services sont créés à partir du nom du PDB
#	****************************************************************************
#	Attention :
#	le script db/create_pdb.sh utilise le script db/create_srv_for_dataguard.sh
#	****************************************************************************
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
	and	c.name not in ( 'PDB\$SEED', 'CDB\$ROOT', 'PDB_SAMPLES' );
"

	line_separator
	while read pdb
	do
		[ x"$pdb" == x ] && continue

		if [ $create_primary_cfg == yes ]
		then
			info "Create stby service for pdb $pdb on cdb $primary"
			exec_cmd "~/plescripts/db/create_srv_for_single_db.sh	\
						-db=$primary -pdb=$pdb	-role=primary"
			LN

			info "(1) Need to start stby services on primary $primary for a short time."
			# Il est important de démarrer les services stby sinon le démarrage
			# des services sur la standby échoura. (1)
			exec_cmd "~/plescripts/db/create_srv_for_single_db.sh	\
						-db=$primary -pdb=$pdb -role=physical_standby"
			LN
		fi

		info "Create services for pdb $pdb on cdb $standby"
		exec_cmd "ssh -t -t $standby_host '. .profile;			\
					~/plescripts/db/create_srv_for_single_db.sh	\
						-db=$standby -pdb=$pdb					\
						-role=primary -start=no'</dev/null"
		LN

		#	Ne pas démarrer les services stby sur la stdy sinon sa plante.
		#	Le faire après la création du broker.
		exec_cmd "ssh -t -t $standby_host '. .profile;				\
					~/plescripts/db/create_srv_for_single_db.sh		\
						-db=$standby -pdb=$pdb						\
						-role=physical_standby -start=no'</dev/null"
		LN

		typeset	oci_stby_service=$(mk_oci_stby_service $pdb)
		typeset	java_stby_service=$(mk_java_stby_service $pdb)

		if [ $create_primary_cfg == yes ]
		then	#(1) Il faut stopper les services stdby sur la primary.
				#	Les services stdby démarreront automatiquement lors de
				#	l'ouverture de la stdby en RO.
			info "(1) Stop stby services on primary $primary :"
			exec_cmd "srvctl stop service -db $primary	\
										-service $oci_stby_service"
			exec_cmd "srvctl stop service -db $primary	\
										-service $java_stby_service"
			LN
		fi

		if [ -d $wallet_path ]
		then
			info "Wallet add sys for $pdb to wallet"
			exec_cmd "ssh -t $standby_host '. .bash_profile;				\
						~/plescripts/db/add_sysdba_credential_for_pdb.sh	\
										-db=$standby -pdb=$pdb'</dev/null"
			LN
		fi

	done<<<"$(sqlplus_exec_query "$query")"
}

#	Instruction pour activer le flashback sur la base standby.
function sql_enable_flashback
{
	set_sql_cmd "recover managed standby database cancel;"
	set_sql_cmd "alter database flashback on;"
	set_sql_cmd "recover managed standby database disconnect;"
}

#	Vérifie :
#		- si l'équivalence ssh entre les serveurs existe.
#		- si la base sur serveur standby existe déjà.
#	return 1 if error, else 0
function check_ssh_prereq_and_if_stby_exist
{
	typeset errors=no

	line_separator
	exec_cmd -c "~/plescripts/shell/test_ssh_equi.sh		\
					-user=oracle -server=$standby_host"
	ret=$?
	LN

	if [ $ret -ne 0 ]
	then
		info "From host $client_hostname :"
		info "$ cd ~/plescripts/ssh"
		info "$ ./setup_ssh_equivalence.sh -user1=oracle -server1=$primary_host -server2=$standby_host"
		LN
		errors=yes
	else
		# L'equivalence existe, teste si la base standby existe sur le serveur.
		line_separator
		exec_cmd -c ssh $standby_host "ps -ef | grep -qE 'ora_pmon_[${standby:0:1}]${standby:1}'"
		if [ $? -eq 0 ]
		then
			error "$standby exists on $standby_host"
			errors=yes
		else
			info "$standby not exists on $standby_host : [$OK]"
		fi
		LN
	fi

	[ $errors == yes ] && return 1 || return 0
}

#	Valide les paramètres.
#	Si la configuration dataguard existe alors il faut utiliser le paramètre -create_primary_cfg=no
#	return 1 if error, else 0
function check_params
{
	typeset errors=no

	line_separator
	typeset -ri c=$(dgmgrl -silent sys/$oracle_password 'show configuration' |\
						grep -E "Primary|Physical" | wc -l 2>/dev/null)
	info "Dataguard broker : $c database configured."
	if [ $create_primary_cfg == yes ]
	then
		if [ $c -ne 0 ]
		then
			error "Dataguard broker configuration exist, add -create_primary_cfg=no"
			errors=yes
		fi
	else
		if [ $c -eq 0 ]
		then
			error "Dataguard broker configuration not exist, remove -create_primary_cfg=no"
			errors=yes
		fi
	fi
	LN

	[ $errors == yes ] && return 1 || return 0
}

#	Vérifie si la base est en mode Archive Log
#	return 1 if error, else 0
function check_log_mode
{
typeset -r query=\
"select
	log_mode
from
	v\$database
;"

	line_separator
	info -n "Log mode archivelog : "
	if [ "$(sqlplus_exec_query "$query" | tail -1)" == "ARCHIVELOG" ]
	then
		info -f "[$OK]"
		LN
		return 0
	else
		info -f "[$KO]"
		info "Execute : ~/plescripts/db/enable_archive_log.sh -db=$primary"
		LN
		return 1
	fi
}

#	Vérifie que le 'Tuned Profile' actif est le même sur les deux serveurs.
#	return 1 if error, else 0
function check_tuned_profile
{
	line_separator
	typeset	-r	local_profile="$(tuned-adm active | awk '{ print $4 }')"
	typeset		stby_profile=$(ssh $standby_host "/usr/sbin/tuned-adm active")
	stby_profile=$(echo $stby_profile|awk '{ print $4 }')
	info -n "Tuned profile $local_profile, on $standby_host $stby_profile : "
	if [ "$local_profile" != "$stby_profile" ]
	then
		info -f "[$KO]"
		info "To enable $local_profile on $standby_host"
		info "$ scp /usr/lib/tuned/$local_profile/tuned.conf root@${standby_host}:/usr/lib/tuned/$local_profile/tuned.conf"
		info "$ ssh root@$standby_host \"tuned-adm profile $local_profile\""
		LN
		return 1
	fi

	info -f "[$OK]"
	LN
	return 0
}

#	Vérifie l'ensemble des prés requis nécessaire pour créer un Dataguard
#	return 1 if error, else 0
function check_prereq
{
	typeset errors=no

	if ! check_ssh_prereq_and_if_stby_exist
	then
		errors=yes
	fi

	if ! check_params
	then
		errors=yes
	fi

	if ! check_log_mode
	then
		errors=yes
	fi

	if ! check_tuned_profile
	then
		errors=yes
	fi

	line_separator
	if [ $errors == yes ]
	then
		error "prereq [$KO]"
		LN
		exit 1
	else
		info "prereq [$OK]"
		LN
	fi
}

function stby_enable_block_change_traking
{
	# Doit être activé sur la stby, ce paramètre est ignoré par le duplicate.
	exec_cmd -c "ssh $standby_host								\
			'. .bash_profile; rman target sys/$oracle_password	\
				@$HOME/plescripts/db/rman/enable_block_change_tracking.sql'"
	LN
}

function stby_backup
{
	#	Nécessaire sinon le backup échoue.
	ssh_stby oracle "rman target sys/$oracle_password	\
							@$HOME/plescripts/db/rman/purge.rman"
	LN

	# CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY; est déjà
	# positionné, je pense que c'est parceque je l'applique sur la Primary avant
	# le duplicate.
	typeset -r db_name="$(get_db_unique_name_for_stby)"
	typeset -r snap=$data/$db_name/snapshot_ctrl_file.f

	# ssh_stby ne fonctionne pas.
	exec_cmd "ssh oracle@$standby_host	\
				\". .bash_profile && rman target sys/$oracle_password	\
				@$HOME/plescripts/db/rman/set_config_stby.rman using \'$snap\'\""
	LN

	if [ $backup == yes ]
	then
		ssh_stby oracle "~/plescripts/db/image_copy_backup.sh"
		LN
	else
		warning "$standby : no backup"
		LN
	fi
}

function dbfs_instructions
{
	line_separator
	warning "Update DBFS configuration on $standby_host"
	LN

	info "$ ssh $standby_host"
	info "$ cd ~/plescripts/db/dbfs"
	LN

	while read pdb
	do
		[ x"$pdb" == x ] && continue || true

		info "$ ./create_dbfs.sh -db=$(to_lower $standby) -pdb=$(to_lower $pdb)"
		LN
	done<<<"$(sqlplus_exec_query "$sql_read_pdbs")"
}

typeset	-r	primary_host=$(hostname -s)

script_start

if test_if_cmd_exists crsctl
then
	typeset	-r crs_used=yes
else
	typeset	-r crs_used=no
	_register_stby_to_GI=no
fi

typeset	-r	data=$(orcl_parameter_value db_create_file_dest)
typeset	-r	fra=$(orcl_parameter_value db_recovery_file_dest)

info "Create dataguard :"
info "	- Primary database          : $primary on $primary_host"
info "	- Physical standby database : $standby on $standby_host"
LN

check_prereq

[ $_setup_network == yes ] && setup_network || true

[ $_setup_primary == yes ] && setup_primary || true

[ $_duplicate == yes ] && duplicate || true

[ $_register_stby_to_GI == yes ] && register_stby_to_GI || true

# Il faut configurer les services avant d'appeler configure_dataguard qui
# démarrera les service stby lors de l'ouverture de la base en RO.
if [ $_create_dataguard_services == yes ]
then
	if [ $crs_used == yes ]
	then
		create_dataguard_services
	else
		create_dataguard_services_no_crs
	fi

	line_separator
	exec_cmd "~/plescripts/db/update_tns_alias_for_dataguard.sh	\
						-db=$primary -pdb=all -dataguard_list=$standby_host"
fi

[ $_configure_dataguard == yes ] && configure_dataguard || true

if [ "$(read_flashback_value)" == YES ]
then
	line_separator
	info "Enable flashback on $standby"
	sqlplus_cmd_on_stby "$(sql_enable_flashback)"
fi

stby_enable_block_change_traking
stby_backup

info "Copy glogin.sql"
exec_cmd -c "scp	$ORACLE_HOME/sqlplus/admin/glogin.sql	\
					$standby_host:$ORACLE_HOME/sqlplus/admin/glogin.sql"
LN

timing 20 "Waiting database synchronisation"
LN

exec_cmd "~/plescripts/db/stby/show_dataguard_cfg.sh"

if [ "$(find ~ -name "*_dbfs.cfg"|wc -l)" != 0 ]
then
	dbfs_instructions
fi

script_stop $ME $primary with $standby
