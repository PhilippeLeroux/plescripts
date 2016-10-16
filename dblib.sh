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

#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function sqlplus_cmd_as # $1 sysdba|sysasm
{
	typeset	-r	priv="$1"
	shift

	fake_exec_cmd sqlplus -s sys/$oracle_password as $priv
	if [ $? -eq 0 ]
	then
		printf "${SPOOL}set echo off\nset timin on\n$@\n" | \
			sqlplus -s sys/$oracle_password as $priv
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
	sqlplus_cmd_as sysdba "$@"
}

#*>	Exécute les commandes "$@" avec sqlplus en sysasm
#*>	Affichage correct sur la sortie std et la log.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function sqlplus_asm_cmd
{
	sqlplus_cmd_as sysasm "$@"
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
