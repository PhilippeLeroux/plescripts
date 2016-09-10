typeset -r	SQL_PROMPT="prompt SQL>"

#	$@ contient une commande à exécuter.
#	La fonction n'exécute pas la commande elle :
#		- affiche le prompt SQL> suivi de la commande.
#		- affiche sur la seconde ligne la commande.
#
#	Le but étant de construire dans une fonction 'les_commandes' l'ensemble des
#	commandes à exécuter à l'aide de to_exec.
#	La fonction 'les_commandes' donnera la liste des commandes à la fonction run_sqlplus
function to_exec
{
cat<<WT
prompt
$SQL_PROMPT $@;
$@
WT
}

#	Exécute les commandes "$@" avec sqlplus en sysdba
function run_sqlplus
{
	fake_exec_cmd sqlplus -s sys/$oracle_password as sysdba
	# N'envoyer que dans la log : info "$@"
	printf "set echo off\nset timin on\n$@\n" | sqlplus -s sys/$oracle_password as sysdba
	LN
}

#	Objectif de la fonction :
#	 Exécute un requête, seul son résultat est affiché, la sortie peut être 'parsée'
#	 Par exemple obtenir la liste de tous les PDBs d'un CDB.
function result_of_query
{
	typeset -r	query="$1"
	printf "whenever sqlerror exit 1\nset term off echo off feed off heading off\n$query" | sqlplus -s sys/$oracle_password as sysdba
}

#	Objectif de la fonction :
#	 Exécute une requête dont le but n'est que l'affichage d'un résultat.
function exec_query
{
	typeset -r	query="$1"
	info "$@"
	printf "whenever sqlerror exit 1\n$query" | sqlplus -s sys/$oracle_password as sysdba
}
