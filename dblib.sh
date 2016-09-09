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
	printf "set echo off\nset timin on\n$@\n" | sqlplus -s sys/$oracle_password as sysdba
	LN
}

function result_of_query
{
	typeset -r	query="$1"
	info "run $query"
	printf "whenever sqlerror exit 1\nset term off echo off feed off heading off\n$query" | sqlplus -s sys/$oracle_password as sysdba
}

function exec_query
{
	typeset -r	query="$1"
	info "run $query"
	printf "whenever sqlerror exit 1\n$query" | sqlplus -s sys/$oracle_password as sysdba
}
