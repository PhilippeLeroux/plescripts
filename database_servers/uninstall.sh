#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	Désinstalle tous les composants d'un serveur ou cluster Oracle.
	Seul root peut exécuter ce script et il doit être exécuté sur le serveur
	concerné.

	[-all]                  : désinstalle tous les composants
	[-databases]            : supprime les bases de données.
	[[!] -oracle]           : désinstalle oracle.
	[[!] -grid]             : désinstalle grid.
	[[!] -disks]            : supprime les disques.
	[[!] -revert_to_master] : repasse sur la config du master.

	-storage=ASM            : Si installation sur FS le préciser !

	Ajouter le flag '!' permet de ne pas effectuer une action avec le paramètre -all.
"

typeset storage=ASM
typeset action_list
typeset -r all_actions="delete_databases remove_oracle_binary remove_grid_binary remove_oracle_disks revert_to_master"

typeset not_flag=no
#	Utiliser lors de l'évaluation de paramètres.
#	Si $1 vaut yes met fin au script, c'est la contenu de la variable not_flag
#	qui doit être passé en paramètre.
function exit_if_not_flag_used
{
	if [ $1 == yes ]
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
			exit_if_not_flag_used $not_flag -emul
			EXEC_CMD_ACTION=NOP
			arg1="-emul"
			shift
			;;

		-storage=*)
			storage=${1##*=}
			shift
			;;

		-all)
			exit_if_not_flag_used $not_flag -all
			action_list=$all_actions
			shift
			;;

		-databases)
			exit_if_not_flag_used $not_flag -databases
			action_list="$action_list delete_databases"
			shift
			;;

		-oracle)
			if [ $not_flag == yes ]
			then
				not_flag=no
				action_list=$(sed "s/ remove_oracle_binary//"<<<"$action_list")
			else
				action_list="$action_list remove_oracle_binary"
			fi
			shift
			;;

		-grid)
			if [ $not_flag == yes ]
			then
				not_flag=no
				action_list=$(sed "s/ remove_grid_binary//"<<<"$action_list")
			else
				action_list="$action_list remove_grid_binary"
			fi
			shift
			;;

		-disks)
			if [ $not_flag == yes ]
			then
				not_flag=no
				action_list=$(sed "s/ remove_oracle_disks//"<<<"$action_list")
			else
				action_list="$action_list remove_oracle_disks"
			fi
			shift
			;;

		-revert_to_master)
			if [ $not_flag == yes ]
			then
				not_flag=no
				action_list=$(sed "s/ revert_to_master//"<<<"$action_list")
			else
				action_list="$action_list revert_to_master"
			fi
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
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

ple_enable_log

script_banner $ME $*

must_be_user root

exit_if_param_invalid storage "FS ASM" "$str_usage"

#	Exécute la commande "$@" en faisant un su - oracle -c
#	Si le premier paramètre est -f l'exécution est forcée.
function suoracle
{
	[ "$1" = -f ] && typeset -r farg="-f" && shift

	exec_cmd $farg "su - oracle -c \"$@\""
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
	info "delete all DBs :"
	while IFS=':' read OSID REM
	do
		[ x$"OSID" == x ] && continue || true

		exec_cmd ~/plescripts/db/remove_all_files_for_db.sh -db=$OSID
	done<<<"$(cat /etc/oratab | grep -E "^[A-Z].*")"
	LN
	
	if [  -f /etc/systemd/system/multi-user.target.wants/oracledb.service ]
	then
		exec_cmd "systemctl disable oracledb"
		exec_cmd "rm -f /etc/systemd/system/multi-user.target.wants/oracledb.service"
		LN
	fi
}

#	Désinstalle Oracle.
function deinstall_oracle
{
	line_separator
	info "deinstall oracle"
	suoracle -f "~/plescripts/database_servers/oracle_uninstall.sh $arg1"

	execute_on_all_nodes "rm -fr /opt/ORCLfmap"
	execute_on_all_nodes "rm -fr /$ORCL_DISK/app/oracle/audit"
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
	exec_cmd umount /$GRID_DISK
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
function remove_oracleasm_disks
{
	line_separator
	info "Remove disks :"
	exec_cmd "~/plescripts/disk/clear_oracle_disk_headers.sh -doit"
	exec_cmd -c "~/plescripts/disk/logout_sessions.sh"
	exec_cmd "systemctl disable oracleasm.service"
	LN

	info "Remove disks on other nodes."
	execute_on_other_nodes "oracleasm scandisks"
	LN

	execute_on_other_nodes "~/plescripts/disk/logout_sessions.sh"
	LN

	execute_on_other_nodes "systemctl disable oracleasm.service"
	LN
}

#	Désinstalle le grid.
function deinstall_grid_12cR1
{
	line_separator
	warning "You must answer the questions, and follow instructions !"
	LN

	sugrid "/mnt/oracle_install/grid/runInstaller -deinstall -home \\\$ORACLE_HOME"
	LN

	execute_on_all_nodes "rm -fr /etc/oraInst.loc"
	LN

	execute_on_all_nodes "rm -fr /etc/oratab"
	LN

	execute_on_all_nodes "rm -fr /$GRID_DISK/app/grid/log"
	LN
}

function deinstall_grid_12cR2
{
	line_separator
	execute_on_all_nodes -c "crsctl stop crs"	# pour un RAC
	exec_cmd -c "crsctl stop has"				# pour un standalone
	LN

	exec_cmd -c "~/plescripts/disk/clear_oracle_afd_disk_headers.sh"
	LN

	execute_on_all_nodes -c "rm -rf /etc/rc.d/init.d/afd"
	execute_on_all_nodes -c "rm -rf /etc/rc.d/init.d/init.ohasd"
	execute_on_all_nodes -c "rm -rf /etc/rc.d/init.d/ohasd"
	LN

	execute_on_all_nodes "rm -rf ${GRID_BASE%/*}/oraInventory"
	LN

	execute_on_all_nodes "find $GRID_BASE/* -maxdepth 1	-type d \
								! -name \"12.2.0.1\" | xargs rm -rf"
	LN

	execute_on_all_nodes "rm -fr $GRID_HOME/*"
	LN

	execute_on_all_nodes "rm -fr /etc/oracle"
	LN

	execute_on_all_nodes "rm -fr /etc/oraInst.loc"
	LN

	execute_on_all_nodes "rm -fr /etc/oratab"
	LN

	execute_on_all_nodes "rm -fr /$GRID_DISK/app/grid/log"
	LN
}

#	============================================================================
#	MAIN
#	============================================================================
script_start

if grep -q remove_oracle_binary <<< "$action_list"
then
	if ! grep -q delete_databases <<< "$action_list"
	then
		typeset	-r	db_present=$(cat /etc/oratab | grep -E "^[A-Z].*")
		if [ x"$db_present" != x ]
		then
			info "Database active, add flag delete_databases"
			action_list="delete_databases $action_list"
		fi
	fi
fi

line_separator
info "Actions : $action_list"
LN
if [ x"$action_list" == x ]
then
	info "$str_usage"
	LN
	exit 1
fi

line_separator
info "Remove components on : $gi_current_node $gi_node_list"
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

if [ $storage == ASM ]
then
	if grep -q remove_grid_binary <<< "$action_list"
	then
		if [ "${GRID_HOME##*/}" == "12.2.0.1" ]
		then
			deinstall_grid_12cR2
		else
			deinstall_grid_12cR1
		fi
	fi
fi

if grep -q remove_oracle_disks <<< "$action_list"
then
	if [ $storage == ASM ]
	then
		if test_if_cmd_exists oracleasm
		then
			remove_oracleasm_disks
		else
			warning "AFD disks not removed : TODO"
		fi
	else
		remove_vg
	fi
fi

exec_cmd -f -c "umount /mnt/oracle_install"
LN

if grep -q revert_to_master <<< "$action_list"
then
	line_separator
	execute_on_other_nodes "plescripts/database_servers/revert_to_master.sh -doit; poweroff"
	exec_cmd "./revert_to_master.sh -doit"
	exec_cmd "poweroff"
	LN
fi

script_stop $ME
