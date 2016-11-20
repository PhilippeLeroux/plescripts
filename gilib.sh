#	Lib permettant d'exécuter sur tous les nœuds d'un RAC un script ou une commande.
#	gi_current_node contient le nom du nœud courant.
#	gi_node_list	contient le nom des autres nœuds pour un RAC.
#	plelib.sh doit être chargée.
# vim: ts=4:sw=4

#	Retourne tous les nœuds du cluster moins le nœud courant.
#	Si le serveur courant n'appartient pas à un cluster la fonction ne retourne rien.
function get_other_nodes
{
	if $(test_if_cmd_exists olsnodes)
	then
		typeset nl=$(olsnodes | xargs)
		if [ x"$nl" != x ]
		then # olsnodes ne retourne rien sur un SINGLE
			sed "s/$(hostname -s) //" <<<"$nl"
		fi
	fi
}

typeset -r gi_node_list=$(get_other_nodes)
typeset -r gi_current_node=$(hostname -s)

#	Exécute la commande "$@" sur tous les autres nœuds du cluster
function execute_on_other_nodes
{
	typeset -r cmd=$(escape_2xquotes "$@")

	for node in $gi_node_list
	do
		exec_cmd "ssh -t -t $node \"$cmd\"</dev/null"
	done
}

#	Exécute la commande "$@" sur tous les nœuds du cluster
function execute_on_all_nodes
{
	typeset -r cmd="$@"

	exec_cmd "$cmd"
	execute_on_other_nodes "$cmd"
}

#	Exécute la commande "$@" sur tous les nœuds du cluster
#	Source le fichier .bash_profile sur les autres nœuds.
function execute_on_all_nodes_v2
{
	typeset -r cmd="$@"

	exec_cmd "$cmd"
	execute_on_other_nodes ". .bash_profile; $cmd"
}
