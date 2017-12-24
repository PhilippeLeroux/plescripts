#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/db/wallet/walletlib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME
	[-no_backup]              Ne pas faire de backup.

	Le script doit être exécuté sur le serveur de la base primaire et
	l'environnement de la base primaire doit être chargé.

Flags de debug :
	Ne pas tester les pré requis.
		-skip_prereq

	setup_network : configuration des tns et listeners des 2 serveurs.
		-skip_setup_network passe cette étape.

	setup_primary : configuration de la base primaire.
		-skip_setup_primary passe cette étape.

	duplicate     : duplication de la base primaire.
		-skip_duplicate passe cette étape.

	register_stby_to_GI : finalise la configuration de la standby
		-skip_register_stby_to_GI passe cette étape.

	configure_dataguard : configure le broker et le dataguard.
		-skip_configure_dataguard passe cette étape.

	create_dataguard_services : crée les services.
		-skip_create_dataguard_services passe cette étape
"

typeset	create_primary_cfg=to_defined
typeset	backup=yes

typeset	_check_prereq=yes
typeset	_setup_primary=yes
typeset	_setup_network=yes
typeset	_duplicate=yes
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

		-no_backup)
			backup=no
			shift
			;;

		-skip_prereq)
			_check_prereq=no
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

exit_if_ORACLE_SID_not_defined

ple_enable_log -params $PARAMS

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
		echo "${dbid}02"
	else # Base créée à partir de la Primary
		echo "${dbid}01"
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
		exec_cmd "sudo -iu grid $script"
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

if [ -f \$TNS_ADMIN/listener.ora ]
then
	if grep -q "# Added by bibi : $standby" \$TNS_ADMIN/listener.ora
	then
		echo "Already configured."
		exit 0
	fi
else
	cp \$TNS_ADMIN/listener.ora \$TNS_ADMIN/listener.ora.bibi.backup
fi

echo "Configuration :"
echo "$standby_sid_list" >> \$TNS_ADMIN/listener.ora
lsnrctl stop
lsnrctl start
EOS

	exec_cmd chmod ug=rwx $script
	exec_cmd "scp $script $standby_host:$script"
	if [ $crs_used == yes ]
	then
		exec_cmd "ssh -t $standby_host sudo -iu grid $script"
	else
		exec_cmd "ssh -t $standby_host '. .bash_profile && $script'"
	fi
	LN
}

function sql_print_redo
{
	set_sql_cmd "set lines 130 pages 45"
	set_sql_cmd "col member for a60"
	set_sql_cmd "break on type skip 1"
	set_sql_cmd "select * from v\$logfile order by type, group#;"
}

#	Création des SRLs sur la base primaire.
function add_stby_redolog
{
	typeset		redo_size_mb=undef
	typeset	-i	nr_redo=-1
	read redo_size_mb nr_redo <<<"$(sqlplus_exec_query "select distinct round(bytes/1024/1024)||'M', count(*) from v\$log group by bytes;" | tail -1)"

	typeset -ri	nr_srl=$(sqlplus_exec_query "select count(*) from v\$logfile where type = 'STANDBY';"|tail -1)

	typeset -ri nr_stdby_redo=nr_redo+1
	info "$primary : $nr_redo redo logs of $redo_size_mb"
	if [ $nr_srl -ne 0 ]
	then
		info "SRLs already exists #$nr_srl."
		LN
	else
		info " --> Add $nr_stdby_redo SRLs of $redo_size_mb"
		sqlplus_cmd "$(sqlcmd_create_stby_redo_logs $nr_stdby_redo $redo_size_mb)"
		LN
	fi

	sqlplus_print_query "$(sql_print_redo)"
	LN
}

#	Configure les fichiers tnsnames sur le serveur primaire et secondaire.
#	Ajoute les alias pour les connexions sur les CDBs, pas les PDBs sur les
#	serveurs primaire et physique.
function setup_tnsnames
{
	line_separator
	info "Add alias for primary and physical CDB on $(hostname -s)"
	LN

	exec_cmd "~/plescripts/db/add_tns_alias.sh	\
					-service=$primary			\
					-host_name=$primary_host"
	LN

	exec_cmd "~/plescripts/db/add_tns_alias.sh	\
					-service=$standby			\
					-host_name=$standby_host"
	LN

	line_separator
	info "Add alias for primary and physical CDB on $standby_host"
	LN

	exec_cmd "ssh $standby_host \". .bash_profile &&					\
									~/plescripts/db/add_tns_alias.sh	\
											-service=$primary			\
											-host_name=$primary_host\""
	LN

	exec_cmd "ssh $standby_host \". .bash_profile &&					\
									~/plescripts/db/add_tns_alias.sh	\
											-service=$standby			\
											-host_name=$standby_host\""
	LN
}

#	Démarre une base standby minimum.
#	Actions :
#		- copie du fichier 'password' de la primaire vers la standby
#		- création du répertoire adump sur le serveur de la standby
#		- puis démarre la standby uniquement avec le paramètre db_name
function start_stby
{
	info "Copy password file."
	exec_cmd scp $ORACLE_HOME/dbs/orapw${primary} ${standby_host}:$ORACLE_HOME/dbs/orapw${standby}
	LN

	line_separator
	info "Create directory $ORACLE_BASE/$standby/adump on $standby_host"
	exec_cmd -c "ssh $standby_host mkdir -p $ORACLE_BASE/admin/$standby/adump"
	LN

	line_separator
	info "Start $standby on $standby_host."

	[ $crs_used == no ] && stdby_update_oratab Y || true

	info "On $standby_host :"
	info "$ echo db_name='$standby' > \$ORACLE_HOME/dbs/init${standby}.ora"
	info "$ export ORACLE_SID=$standby"
	info "$ sqlplus -s sys/Oracle12 as sysdba <<<\"startup nomount\""
	LN

	ssh -t -t $standby_host<<-EO_SSH_STBY > /tmp/stby_startup.log
	rm -f $ORACLE_HOME/dbs/sp*${standby}* $ORACLE_HOME/dbs/init*${standby}*
	echo "db_name='$standby'" > $ORACLE_HOME/dbs/init${standby}.ora
	export ORACLE_SID=$standby
	\sqlplus -s sys/Oracle12 as sysdba<<EO_SQL_DBSTARTUP
	whenever sqlerror exit 1;
	startup nomount
	EO_SQL_DBSTARTUP
	exit \$?
	EO_SSH_STBY
	ret=$?

	if [ $ret -ne 0 ]
	then
		clean_log_file /tmp/stby_startup.log
		cat /tmp/stby_startup.log | tee -a $PLELIB_LOG_FILE
		rm /tmp/stby_startup.log
		LN
	fi

	info "startup nomount return $ret"
	LN
}

#	Lance la duplication de la base avec RMAN
function run_duplicate
{
	typeset stby_db_unique_name="$(get_db_unique_name_for_stby)"
	# Sur la Primary et sur la Physical les db_name sont identiques.
	typeset db_name=$(orcl_parameter_value db_name)

	info "Physical standby"
	info "db_name        : $db_name"
	info "db_unique_name : $stby_db_unique_name"
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
#		- démarre la synchro
#		- enregistre la standby dans le GI.
function register_stby_to_GI
{
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
	timing 10 "Wait recover"
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
function create_dataguard_services
{
	line_separator
	while read pdb
	do
		[ x"$pdb" == x ] && continue || true

		exec_cmd "~/plescripts/db/create_srv_for_dataguard.sh	\
								-db=$primary -pdb=$pdb			\
								-standby=$standby -standby_host=$standby_host</dev/null"

		if [ -d $wallet_path ]
		then
			info "Wallet add sys for $pdb to wallet"
			exec_cmd "ssh -t $standby_host '. .bash_profile;				\
						~/plescripts/db/add_sysdba_credential_for_pdb.sh	\
										-db=$standby -pdb=$pdb'</dev/null"
			LN
		fi

	done<<<"$(get_rw_pdbs $ORACLE_SID)"
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
function test_if_dataguard_configuration_exists
{
	line_separator
	typeset -ri c=$(dgmgrl -silent sys/$oracle_password 'show configuration' |\
						grep -E "Primary|Physical" | wc -l 2>/dev/null)
	[ $c -eq 0 ] && create_primary_cfg=yes || create_primary_cfg=no
	info "Dataguard broker : $c database configured."
	LN
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
	line_separator
	info "Enable block change tracking."
	exec_cmd -c "ssh $standby_host								\
			'. .bash_profile; rman target sys/$oracle_password	\
				@$HOME/plescripts/db/rman/enable_block_change_tracking.sql'"
	LN
}

function stby_create_oracle_home_links
{
	info "Create links for user oracle."
	LN

	exec_cmd "ssh $standby_host '. .bash_profile && plescripts/db/create_links.sh -db=$standby'"
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

	while read cfg_fullpath
	do
		[ x"$cfg_fullpath" == x ] && continue || true

		cfg_file=${cfg_fullpath##*/}
		pdb_name=$(cut -d_ -f1<<<"$cfg_file")

		info "$ ./create_dbfs.sh -db=$(to_lower $standby) -pdb=$(to_lower $pdb_name)"
		LN
	done<<<"$(find ~ -name "*_dbfs.cfg")"
}

typeset	-r	primary=$ORACLE_SID
typeset	-r	primary_host=$(hostname -s)
typeset	-r	dbid=${primary:0:${#primary}-2}
case "${primary:${#primary}-2}" in
	01)
		typeset -r	standby_host=${primary_host:0:${#primary_host}-2}02
		typeset	-r	standby=$(to_upper ${dbid}02)
		;;
	02)
		typeset -r	standby_host=${primary_host:0:${#primary_host}-2}01
		typeset	-r	standby=$(to_upper ${dbid}01)
		;;
	*)
		error "ORACLE_SID $ORACLE_SID not conform, suffix must be 01 or 02"
		LN
		exit 1
		;;
esac

script_start

if command_exists crsctl
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

test_if_dataguard_configuration_exists

[ $_check_prereq == yes ] && check_prereq || true

[ $_setup_network == yes ] && setup_network || true

[ $_setup_primary == yes ] && setup_primary || true

[ $_duplicate == yes ] && duplicate || true

stby_create_oracle_home_links

[ $_register_stby_to_GI == yes ] && register_stby_to_GI || true

[ $_configure_dataguard == yes ] && configure_dataguard || true

line_separator
info "Copy glogin.sql"
exec_cmd -c "scp	$ORACLE_HOME/sqlplus/admin/glogin.sql	\
					$standby_host:$ORACLE_HOME/sqlplus/admin/glogin.sql"
LN

if [ "$(read_flashback_value)" == YES ]
then
	line_separator
	info "Enable flashback on $standby"
	sqlplus_cmd_on_stby "$(sql_enable_flashback)"
	LN
fi

stby_enable_block_change_traking

[ $_create_dataguard_services == yes ] && create_dataguard_services || true

stby_backup

timing 20 "Waiting database synchronization"
LN

exec_cmd "~/plescripts/db/stby/show_dataguard_cfg.sh"

if [ "$(find ~ -name "*_dbfs.cfg"|wc -l)" != 0 ]
then
	dbfs_instructions
fi

script_stop $ME $primary with $standby
