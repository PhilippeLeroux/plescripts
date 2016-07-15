#!/bin/bash

#	ts=4	sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	Désinstalle tous les composants d'un serveur ou cluster Oracle.
	Seul root peut exécuter ce script et il doit être exécuté sur le serveur
	concerné.

	[-all]          : désinstalle tous les composants
	[-databases]    : supprime les bases de données.
	[[!] -oracle]   : désinstalle oracle.
	[[!] -grid]     : désinstalle grid.
	[[!] -disks]    : supprime les disques.

	-type=ASM       : type d'installation FS ou ASM

	Ajouter le flag '!' permet de ne pas effectuer une action avec le paramètre -all.
"

info "$ME $@"

typeset type=ASM
typeset action_list
typeset -r all_actions="delete_databases remove_oracle_binary remove_grid_binary remove_disks"

typeset not_flag=no
#	Utiliser lors de l'évaluation de paramètres.
#	Si $1 vaut yes met fin au script, c'est la contenu de la variable not_flag
#	qui doit être passé en paramètre.
function exit_if_yes
{
	if [ $1 = yes ]
	then
		error "! not supported with $2"
		info "$str_usage"
		exit 1
	fi
}

while [ $# -ne 0 ]
do
	case $1 in
		!)
			not_flag=yes
			shift
			;;

		-emul)
			exit_if_yes $not_flag -emul
			EXEC_CMD_ACTION=NOP
			arg1="-emul"
			shift
			;;

		-type=*)
			exit_if_yes $not_flag -all
			type=${1##*=}
			shift
			;;

		-all)
			exit_if_yes $not_flag -databases
			action_list=$all_actions
			shift
			;;

		-databases)
			exit_if_yes $not_flag -databases
			action_list="$action_list delete_databases"
			shift
			;;

		-oracle)
			if [ $not_flag = yes ]
			then
				not_flag=no
				action_list=$(sed "s/ remove_oracle_binary//"<<<"$action_list")
			else
				action_list="$action_list remove_oracle_binary"
			fi
			shift
			;;

		-grid)
			if [ $not_flag = yes ]
			then
				not_flag=no
				action_list=$(sed "s/ remove_grid_binary//"<<<"$action_list")
			else
				action_list="$action_list remove_grid_binary"
			fi
			shift
			;;

		-disks)
			if [ $not_flag = yes ]
			then
				not_flag=no
				action_list=$(sed "s/ remove_disks//"<<<"$action_list")
			else
				action_list="$action_list remove_disks"
			fi
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			rm -f $PLELIB_LOG_FILE
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

[ $USER != root ] && error "Only root !" && exit 1

exit_if_param_invalid type "FS ASM" "$str_usage"

info "Actions : $action_list"
if [ x"$action_list" == x ]
then
	info "$str_usage"
	exit 1
fi

#	Les fonctions get_other_nodes & root_execute_on_other_nodes sont dupliquées
#	dans db/delete_db.sh

#	Retourne tous les noeuds du cluster moins le noeud courant.
#	Si le serveur courant n'appartient pas à un cluster la fonction
#	ne retourne rien.
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

typeset -r node_list=$(get_other_nodes)
typeset -r current_node=$(hostname -s)

#	Exécute la commande "$@" sur tous les autres noeuds du cluster
function root_execute_on_other_nodes
{
	typeset -r cmd="$@"

	for node in $node_list
	do
		exec_cmd "ssh $node $cmd"
	done
}

#	Exécute la commande "$@" sur tous les noeuds du cluster
function root_execute_on_all_nodes
{
	typeset -r cmd="$@"

	exec_cmd "$cmd"
	root_execute_on_other_nodes "$cmd"
}

#	Exécute la commande "$@" en faisant un su - oracle -c
#	Si le premier paramètre est -f l'exécution est forcée.
function suoracle
{
	[ "$1" = -f ] && typeset -r arg=$1 && shift

	exec_cmd $arg "su - oracle -c \"$@\""
}

#	Exécute la commande "$@" en faisant un su - grid -c
#	Si le premier paramètre est -c le script n'est pas interrompu sur une erreur
function sugrid
{
	[ "$1" = -c ] && typeset -r arg=$1 && shift

	exec_cmd $arg "su - grid -c \"$@\""
}

#	Supprime toutes les bases de données installées.
function delete_all_db
{
	line_separator
	info "delete all DB :"
	cat /etc/oratab | grep -E "^[A-Z].*# line added by Agent" |\
	while IFS=':' read OSID REM
	do
		suoracle "~/plescripts/db/delete_db.sh -db=$OSID"
	done
	LN
}

#	Désinstalle Oracle.
function deinstall_oracle
{
	line_separator
	info "deinstall oracle"
	suoracle -f "~/plescripts/database_servers/uninstall_oracle.sh $arg1"

	root_execute_on_all_nodes "rm -fr /opt/ORCLfmap"
	root_execute_on_all_nodes "rm -fr /u01/app/oracle/audit"
	LN

	typeset -r service_file=/usr/lib/systemd/system/oracledb.service
	if [ -f $service_file ]
	then	# Uniquement sur les DB sur FS
		exec_cmd -c "systemctl stop oracledb.service"
		exec_cmd -c "systemctl disable oracledb.service"
		exec_cmd "rm -f $service_file"
		LN
	fi
}

#	FS uniquement : supprime le VG et les disques
function remove_vg
{
	line_separator
	exec_cmd "umount /u01/app/oracle/oradata"
	exec_cmd "sed -i "/vg_oradata-lv_oradata/d" /etc/fstab"
	fake_exec_cmd "vgremove vg_oradata<<<\"yy\""
	if [ $? -eq 0 ]
	then
		vgremove vg_oradata <<EOS
y
y
EOS
	fi
	exec_cmd -c "~/plescripts/disk/logout_sessions.sh"
	LN
}

#	GI uniquement : supprime tous les disques.
function remove_disks
{
	line_separator
	info "Supprime les disques :"
	exec_cmd "~/plescripts/disk/clear_oracle_disk_headers.sh -doit"
	exec_cmd -c "~/plescripts/disk/logout_sessions.sh"
	exec_cmd "systemctl disable oracleasm.service"
	LN

	info "Supprime les disques sur les autres nœuds."
	root_execute_on_other_nodes "oracleasm scandisks"
	LN

	root_execute_on_other_nodes "~/plescripts/disk/logout_sessions.sh"
	LN

	root_execute_on_other_nodes "systemctl disable oracleasm.service"
	LN
}

#	Désinstalle le grid.
function deinstall_grid
{
	line_separator
	sugrid "/mnt/oracle_install/grid/runInstaller -deinstall -home \\\$ORACLE_HOME"
	LN

	root_execute_on_all_nodes "rm -fr /etc/oraInst.loc"
	LN

	root_execute_on_all_nodes "rm -fr /etc/oratab"
	LN

	root_execute_on_all_nodes "rm -fr /u01/app/grid/log"
	LN
}

#	============================================================================
#	MAIN
#	============================================================================
line_separator
info "Remove component on : $current_node $node_list"
line_separator
LN

exec_cmd -f -c "mount /mnt/oracle_install"
LN

if grep -q delete_databases <<< "$action_list"
then
	delete_all_db
fi

if grep -q remove_oracle_binary <<< "$action_list"
then
	deinstall_oracle
fi

if [ $type != FS ]
then
	if grep -q remove_grid_binary <<< "$action_list"
	then
		deinstall_grid
	fi
fi

if grep -q remove_disks <<< "$action_list"
then
	[ $type == ASM ] && remove_disks || remove_vg
fi

exec_cmd -f -c "umount /mnt/oracle_install"
LN

line_separator

info "Éventuellement faire un rm -rf /tmp/* en root"
LN
