#	Lib permettant d'exécuter sur tous les nœuds d'un RAC un script ou une commande.
#	gi_current_node contient le nom du nœud courant.
#	gi_node_list	contient le nom des autres nœuds pour un RAC.
#	plelib.sh doit être chargée.
# vim: ts=4:sw=4

#	Retourne tous les nœuds du cluster moins le nœud courant.
#	Si le serveur courant n'appartient pas à un cluster la fonction ne retourne rien.
function _get_other_nodes
{
	if $(test_if_cmd_exists olsnodes)
	then
		# Si le Grid n'est pas démarré olsnodes ne fonctionne pas.
		typeset nl=$(olsnodes | xargs)
		if [[ "$nl" =~ "PRCO" ]]
		then
			echo
			return 1
		elif [ x"$nl" != x ]
		then # olsnodes ne retourne rien sur un SINGLE
			sed "s/$(hostname -s)//"<<<"$nl"
		fi
	fi

	return 0
}

typeset -r	gi_node_list=$(_get_other_nodes)
typeset -r	gi_current_node=$(hostname -s)
typeset	-ri	gi_count_nodes=$(( $(wc -w<<<"$gi_node_list") + 1 ))

#	Exécute la commande "$@" sur tous les autres nœuds du cluster
#	if $1 == -c script not interupted on error.
function execute_on_other_nodes
{
	[ $gi_count_nodes -eq 1 ] && return 0 || true

	if [ "$1" == "-c" ]
	then
		typeset -r first_arg="-c"
		shift
	else
		typeset -r first_arg
	fi

	typeset -r cmd=$(escape_2xquotes "$@")

	for node in $gi_node_list
	do
		exec_cmd $first_arg "ssh -t -t $node \"$cmd\"</dev/null"
	done
}

#	Exécute la commande "$@" sur tous les nœuds du cluster
#	if $1 == -c script not interupted on error.
function execute_on_all_nodes
{
	if [ "$1" == "-c" ]
	then
		typeset -r first_arg="-c"
		shift
	else
		typeset -r first_arg
	fi

	typeset -r cmd="$@"

	exec_cmd $first_arg "$cmd"
	execute_on_other_nodes $first_arg "$cmd"
}

#	Exécute la commande "$@" sur tous les nœuds du cluster
#	Source le fichier .bash_profile sur les autres nœuds.
#	if $1 == -c script not interupted on error.
function execute_on_all_nodes_v2
{
	if [ "$1" == "-c" ]
	then
		typeset -r first_arg="-c"
		shift
	else
		typeset -r first_arg
	fi

	typeset -r cmd="$@"

	exec_cmd $first_arg "$cmd"
	execute_on_other_nodes $first_arg ". .bash_profile; $cmd"
}

# print to stdout Grid Version :
#	12.1.0.2
# or
#	12.2.0.1
function grid_version
{
	$ORACLE_HOME/OPatch/opatch lsinventory		|\
		grep "Oracle Grid Infrastructure 12c"	|\
		awk '{ print $5 }'						|\
		cut -d. -f1-4
}

# print to stdout Grid Version :
#	12cR1
# or
#	12cR2
function grid_release
{
	case "$(grid_version)" in
		12.1.*)
			echo 12cR1
			;;
		12.2.*)
			echo 12cR2
			;;
		*)
			echo "Unknow release"
	esac
}
