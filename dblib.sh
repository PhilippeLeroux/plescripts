# vim: ts=4:sw=4

if [ x"$plelib_banner" == x ]
then
	echo "inclure plelib avant dblib"
	exit 1
fi

. ~/plescripts/global.cfg

#	La variable SPOOL permet de loger la sortie de sqplus.
if [ "$PLELIB_OUTPUT" == FILE ]
then
	typeset -r SPOOL="spool $PLELIB_LOG_FILE append\n"
else
	typeset -r SPOOL
fi

typeset -r	SQL_PROMPT="prompt SQL>"

function exit_if_ORACLE_SID_not_defined
{
	if [[ x"$ORACLE_SID" == x || "$ORACLE_SID" == NOSID ]]
	then
		error "$(hostname -s) : ORACLE_SID not define."
		LN
		exit 1
	fi
}

# print yes to stdout if dataguarg configutation available or no
function dataguard_config_available
{
	dgmgrl -silent sys/$oracle_password 'show configuration' >/dev/null 2>&1
	[ $? -eq 0 ] && echo "yes" || echo "no"
}

#*> $1 database name
#*> print to stdout database role : primary or physical
function read_database_role
{
	to_lower $(dgmgrl -silent sys/Oracle12 'show configuration'	|\
							grep $1 | cut -d- -f2 | awk '{ print $1 }')
}

# arrays physical_list & stby_server_list must be declared
function load_stby_database
{
	typeset name
	while read name
	do
		physical_list+=( $name )
	done<<<"$(dgmgrl sys/$oracle_password 'show configuration'	|\
					grep "Physical standby" | awk '{ print $1 }')"

	typeset stby_name
	for stby_name in ${physical_list[*]}
	do
		stby_server_list+=($(tnsping $stby_name | tail -2 | head -1 |\
					sed "s/.*(\s\?HOST\s\?=\s\?\(.*\)\s\?)\s\?(\s\?PORT.*/\1/"))
	done

}

# print to stdout primary database name
function read_primary_name
{
	dgmgrl sys/$oracle_password 'show configuration'	|\
				grep "Primary database" | awk '{ print $1 }'
}

#*>	$@ contient une commande à exécuter.
#*>	La fonction n'exécute pas la commande elle :
#*>		- affiche le prompt SQL> suivi de la commande.
#*>		- affiche sur la seconde ligne la commande.
#*>
#*>	Le but étant de construire dans une fonction 'les_commandes' l'ensemble des
#*>	commandes à exécuter à l'aide de set_sql_cmd.
#*>	La fonction 'les_commandes' donnera la liste des commandes à la fonction sqlplus_cmd
function set_sql_cmd
{
cat<<WT
prompt
$SQL_PROMPT $@;
$@
WT
}

#*> $1 chaine de connection
#*>	Exécute les commandes "$@" avec sqlplus
#*>	Affichage correct sur la sortie std et la log.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function sqlplus_cmd_with
{
	typeset connect_string="$1"
	shift
	if [ "$1" == as ]
	then
		typeset -r connect_string="$connect_string as $2"
		shift 2
	fi

	typeset	-r	db_cmd="$*"
	fake_exec_cmd sqlplus -s "$connect_string"
	if [ $? -eq 0 ]
	then
		printf "${SPOOL}set timin on\n$db_cmd\n" | \
			sqlplus -s $connect_string
		return $?
	else
		printf "${SPOOL}set timin on\n$db_cmd\n"
		return 1
	fi
}

#*>	Exécute les commandes "$@" avec sqlplus en sysdba
#*>	Affichage correct sur la sortie std et la log.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function sqlplus_cmd
{
	sqlplus_cmd_with "sys/$oracle_password as sysdba" "$@"
}

#*>	Exécute les commandes "$@" avec sqlplus en sysasm
#*>	Affichage correct sur la sortie std et la log.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function sqlplus_asm_cmd
{
	fake_exec_cmd sqlplus -s / as sysasm
	if [ $? -eq 0 ]
	then
		printf "${SPOOL}set echo off\nset timin on\n$@\n" | \
			sqlplus -s / as sysasm
		return 0
	else
		printf "${SPOOL}set echo off\nset timin on\n$@\n"
		return 1
	fi
}

#*>	Objectif de la fonction :
#*>	 Exécute une requête, seul son résultat est affiché, la sortie peut être 'parsée'
#*>	 Par exemple obtenir la liste de tous les PDBs d'un CDB.
#*>	N'inscrit rien dans la log.
function sqlplus_exec_query
{
	typeset -r	seq_query="$1"
	printf "whenever sqlerror exit 1\nset term off echo off feed off heading off\n$seq_query" | \
		sqlplus -s sys/$oracle_password as sysdba
}

#*>	Objectif de la fonction :
#*>	 Exécute une requête dont le but n'est que l'affichage d'un résultat.
#*>	Affiche la requête exécutée.
function sqlplus_print_query
{
	typeset -r	spq_query="$1"
	fake_exec_cmd "sqlplus -s sys/$oracle_password as sysdba"
	info "$query"
	printf "${SPOOL}whenever sqlerror exit 1\n$spq_query" | \
		sqlplus -s sys/$oracle_password as sysdba
	LN
}

#*> $1 db name
#*> $2 service name
#*>
#*> return 1 if db name or service name not exists, else return 0
function service_exists
{
	if grep -qE "^PRCR-1001"<<<"$(srvctl config service -db $1 -service $2)"
	then
		return 1
	else
		return 0
	fi
}

#*> $1 db name
#*> $2 service name
#*>
#*> return 0 if service running else return 1
function service_running
{
	typeset -r db_name_l=$1
	typeset -r service_name_l=$(to_lower $2)
	grep -iqE "Service $service_name_l is running.*"<<<"$(LANG=C srvctl status service -db $db_name_l -s $service_name_l)"
}

#*> $1 db name
#*> $2 service name
#*>
#*> exit 1 if service not exists.
function exit_if_service_not_exists
{
	typeset -r db_name_l=$1
	typeset -r service_name_l=$2

	info -n "Database $db_name_l, service $service_name_l exists : "
	if service_exists $db_name_l $service_name_l
	then
		info -f "$OK"
		LN
	else
		info -f "$KO"
		LN
		exit 1
	fi
}


#*> $1	db name
#*> $2	service name
#*>
#*> exit 1 if service name not running else return 0
function exit_if_service_not_running
{
	typeset	-r	db_name_l="$1"
	typeset	-r	service_name_l="$2"

	info -n "Database $db_name_l, service $service_name_l running "
	if service_running $db_name_l $service_name_l
	then
		info -f "$OK"
		LN
	else
		info -f "$KO"
		LN
		exit 1
	fi
}

#*> $1 pdb name
#*>
#*> return db name
function extract_db_name_from
{
	typeset	-r pdb_name_l="$1"
	to_lower $(sed "s/\([a-z]*\)[0-9]*/\1/" <<<$pdb_name_l)
}

#*>	$1 pdb name
#*>
#*> return associate oci service name
function mk_oci_service
{
	echo $(to_lower "$1")_oci
}

#*>	$1 pdb name
#*>
#*> return associate oci service name for stby
function mk_oci_stby_service
{
	echo $(to_lower "$1")_stby_oci
}

#*>	$1 pdb name
#*>
#*> return associate java service name
function mk_java_service
{
	echo $(to_lower "$1")_java
}

#*>	$1 pdb name
#*>
#*> return associate java service name
function mk_java_stby_service
{
	echo $(to_lower "$1")_stby_java
}
