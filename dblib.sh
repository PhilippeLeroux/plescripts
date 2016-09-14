if [ x"$plelib_banner" == x ]
then
	echo "inclure plelib avant dblib"
	exit 1
fi

#	La variable SPOOL permet de loger la sortie de sqplus.
if [ "$PLELIB_OUTPUT" == FILE ]
then
	typeset -r SPOOL="spool $PLELIB_LOG_FILE append\n"
else
	typeset -r SPOOL
fi

typeset -r	SQL_PROMPT="prompt SQL>"

#	$@ contient une commande à exécuter.
#	La fonction n'exécute pas la commande elle :
#		- affiche le prompt SQL> suivi de la commande.
#		- affiche sur la seconde ligne la commande.
#
#	Le but étant de construire dans une fonction 'les_commandes' l'ensemble des
#	commandes à exécuter à l'aide de to_exec.
#	La fonction 'les_commandes' donnera la liste des commandes à la fonction sqlplus_cmd
function to_exec
{
cat<<WT
prompt
$SQL_PROMPT $@;
$@
WT
}

#	Exécute les commandes "$@" avec sqlplus en sysdba
#	Affichage correct sur la sortie std et la log.
function sqlplus_cmd
{
	fake_exec_cmd sqlplus -s sys/$oracle_password as sysdba
	printf "${SPOOL}set echo off\nset timin on\n$@\n" | \
		sqlplus -s sys/$oracle_password as sysdba 
	LN
}

#	Objectif de la fonction :
#	 Exécute une requête, seul son résultat est affiché, la sortie peut être 'parsée'
#	 Par exemple obtenir la liste de tous les PDBs d'un CDB.
#	N'inscrit rien dans la log.
function sqlplus_exec_query
{
	typeset -r	seq_query="$1"
	printf "whenever sqlerror exit 1\nset term off echo off feed off heading off\n$seq_query" | \
		sqlplus -s sys/$oracle_password as sysdba
}

#	Objectif de la fonction :
#	 Exécute une requête dont le but n'est que l'affichage d'un résultat.
#	Affiche la requête exécutée.
function sqlplus_print_query
{
	typeset -r	spq_query="$1"
	fake_exec_cmd "sqlplus -s sys/$oracle_password as sysdba"
	info "$query"
	printf "${SPOOL}whenever sqlerror exit 1\n$spq_query" | \
		sqlplus -s sys/$oracle_password as sysdba
	LN
}
