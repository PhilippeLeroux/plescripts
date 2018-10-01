#	Lib permettant d'exécuter sur tous les nœuds d'un RAC un script ou une commande.
#	gi_current_node contient le nom du nœud courant.
#	gi_node_list	contient le nom des autres nœuds pour un RAC.
#	plelib.sh doit être chargée.
# vim: ts=4:sw=4

#*>	Retourne tous les nœuds du cluster moins le nœud courant.
#*>	Si le serveur courant n'appartient pas à un cluster la fonction ne retourne rien.
function _get_other_nodes
{
	if command_exists olsnodes
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
# Dans le cas d'un Dataguard gi_count_nodes vaudra 1.
typeset	-ri	gi_count_nodes=$(( $(wc -w<<<"$gi_node_list") + 1 ))

#*>	Exécute la commande "$@" sur tous les autres nœuds du cluster
#*>	if $1 == -c script not interupted on error.
#*>	Le profile n'est pas sourcé.
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

#*>	Exécute la commande "$@" sur tous les nœuds du cluster
#*>	if $1 == -c script not interupted on error.
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

#*>	Exécute la commande "$@" sur tous les nœuds du cluster
#*>	Source le fichier .bash_profile sur les autres nœuds.
#*>	if $1 == -c script not interupted on error.
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

#*> print to stdout Grid Version :
#*>	12.1.0.2, 12.2.0.1, 18.0.0.0, ...
function grid_version
{
	# Certains scripts root incluent la lib et la variable n'est pas définie.
	# Les scripts root n'utilisent pas cette fonction.
	[ x"$ORACLE_HOME" == x ] && return 0 || true

	$ORACLE_HOME/OPatch/opatch lsinventory					|\
		grep -E "Oracle Grid Infrastructure [0-9][0-9]."	|\
		awk '{ print $5 }'									|\
		cut -d. -f1-4
}

#*> print to stdout Grid Version :
#*>	12cR1, 12cR2, 18c, ...
function grid_release
{
	typeset gv=$(grid_version)
	case "$gv" in
		12.1.*)
			echo 12cR1
			;;
		12.2.*)
			echo 12cR2
			;;
		18.0)
			echo 18c
			;;
		*)
			echo "Unknow release : '$gv'"
	esac
}

#*> $1 12.1, 12.2 or 18.0
#*> print to stdout yes or no
#*> Wallet don't work with standalone 12.2 with ASM
function enable_wallet
{
	case "$1" in
		12.1)
			echo yes
			;;

		12.2|18.0)
			if command_exists crsctl
			then
				if [ $gi_count_nodes -gt 1 ]
				then # Avec le RAC le wallet fonctionne.
					echo yes
				else # Impossible de démarrer la base avec le wallet.
					echo no
				fi
			else # Sur FS pas de problème.
				echo yes
			fi
			;;
	esac
}


#*> [$1] max load avg default value 3.
#*> Si la mémoire de l'OS est inférieur aux pré requis alors il peut y avoir un
#*> très fort Load Average (causé par le process gdb), donc dans ce cas la
#*> fonction attend qu'il soit descendu.
#*> Le problème survient surtout dans les 10 à 15mn après le démarrage de la base,
#*> mais il peut se produire n'importe quand.
#*>
#*> Bug : http://www.usn-it.de/index.php/2017/06/20/oracle-rac-12-2-high-load-on-cpu-from-gdb-when-node-missing/
#*> J'ai désactivé diagsnap, mais au cas ou je conserve la fonction.
#*> Si la variable TEST_HIGH_LAVG vaut enable alort le test est fait.
#*> Soit la définir dans local.cfg ou dans le profile des comptes grid et/ou oracle.
function wait_if_high_load_average
{
	[ "$TEST_HIGH_LAVG" != enable ] && return || true

	if		[[ "$USER" == "grid"	&& "$(grid_release)" == "12cR2" ]]	\
		||	[[ "$USER" == "oracle"	&& "$(read_orcl_release)" == "12.2" ]]
	then
		[ $# -eq 0 ] && typeset -i max_load_avg=3 || typeset -i max_load_avg=$1

		if [ $(get_os_memory_mb) -lt $oracle_memory_mb_prereq ]
		then
			line_separator
			exec_cmd ~/plescripts/db/wait_if_high_load_average.sh -max_load_avg=$max_load_avg
		fi
	fi
}
