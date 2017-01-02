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
	typeset -r connect_string="$1"
	shift
	fake_exec_cmd sqlplus -s "$connect_string"
	if [ $? -eq 0 ]
	then
		printf "${SPOOL}set echo off\nset timin on\n$@\n" | \
			sqlplus -s $connect_string
		return 0
	else
		printf "${SPOOL}set echo off\nset timin on\n$@\n"
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

#*> $1	db name
#*> $2	pdb name
#*> $3	service name
#*>
#*> exit if service name not running else return 0
function exit_if_service_not_running
{
	typeset	-r	db_name_l="$1"
	typeset	-r	pdb_name_l="$2"
	typeset	-r	service_name_l="$3"

	info -n "Database $db_name_l, pdb $pdb_name_l : service $service_name_l running "
	if grep -iqE "Service $service_name_l is running.*"<<<"$(LANG=C srvctl status service -db $db_name_l)"
	then
		info -f "$OK"
		LN
		return 0
	else
		info -f "$KO"
		LN
		info "$str_usage"
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
function make_oci_service_name_for
{
	typeset	-r pdb_name_l=$(to_upper "$1")
	echo pdb${pdb_name_l}_oci
}

#*>	$1 pdb name
#*>
#*> return associate java service name
function make_java_service_name_for
{
	typeset	-r pdb_name_l=$(to_upper "$1")
	echo pdb${pdb_name_l}_java
}

