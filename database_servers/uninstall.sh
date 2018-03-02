#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
if command_exists olsnodes
then
	typeset	-r	olsnodes_ok=yes
	warning "Si le script est exécuté plusieurs fois supprimer $(which olsnodes)."
	warning "Sinon le script risque de bloquer."
	LN
else
	typeset	-r	olsnodes_ok=no
fi
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME
	Désinstalle les composants d'un serveur ou cluster Oracle.
	Seul root peut exécuter ce script et il doit être exécuté sur le serveur
	concerné.

	Préciser un des 2 flags :
	    [-oracle] : désinstalle oracle.
	    [-grid]   : désinstalle grid.

	En cas d'échec lors de la désinstallation du grid préciser -db_type lors
	de la prochaine exécution : -db_type=[single|rac]

	Si le script est exécute plusieurs fois supprimer olsnodes.
"

typeset		action
typeset		db_type=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			arg1="-emul"
			shift
			;;

		-oracle)
			if [ x"$action" != x ]
			then
				error "Un seul flag."
				LN
				exit 1
			fi
			action="remove_oracle_binary"
			shift
			;;

		-grid)
			if [ x"$action" != x ]
			then
				error "Un seul flag."
				LN
				exit 1
			fi
			action="remove_grid_binary"
			shift
			;;

		-db_type=*)
			db_type=${1##*=}
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

must_be_user root

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

#	Désinstalle Oracle.
function deinstall_oracle
{
	line_separator
	suoracle -f "~/plescripts/database_servers/oracle_uninstall.sh $arg1"

	execute_on_all_nodes "rm -fr /opt/ORCLfmap"
	execute_on_all_nodes "rm -fr /$orcl_disk/app/oracle/audit"
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

#	GI uniquement : supprime tous les disques.
function remove_oracleasm_disks
{
	line_separator
	info "Remove disks :"
	exec_cmd "~/plescripts/disk/clear_oracleasm_disk_headers.sh -doit"
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

	execute_on_all_nodes "rm -fr /$grid_disk/app/grid/log"
	LN

	execute_on_all_nodes "rm -fr $GRID_HOME/*"
	LN

	execute_on_all_nodes "rm -fr $GRID_BASE/*"
	LN

	execute_on_all_nodes "rm -fr /$grid_disk/app/oraInventory"
	LN
}

function deinstall_grid_12cR2
{
	line_separator
	execute_on_all_nodes -c "systemctl disable ohasd.service"
	execute_on_all_nodes -c "systemctl disable oracle-ohasd.service"
	execute_on_all_nodes -c "systemctl disable oracle-tfa.service"
	execute_on_all_nodes -c "systemctl stop ohasd.service"
	execute_on_all_nodes -c "systemctl stop oracle-ohasd.service"
	execute_on_all_nodes -c "systemctl stop oracle-tfa.service"
	LN

	line_separator
	execute_on_all_nodes -c "rmmod oracleafd"
	LN

	line_separator
	execute_on_all_nodes -c "rm -rf /etc/rc.d/init.d/afd"
	execute_on_all_nodes -c "rm -rf /etc/rc.d/init.d/init.ohasd"
	execute_on_all_nodes -c "rm -rf /etc/rc.d/init.d/ohasd"
	LN

	line_separator
	execute_on_all_nodes "rm -fr /etc/oracle"
	execute_on_all_nodes "rm -fr /etc/oraInst.loc"
	execute_on_all_nodes "rm -fr /etc/oratab"
	LN

	line_separator
	execute_on_all_nodes "rm -rf /u01/*"
	execute_on_all_nodes "rm -rf /u02/*"
	LN

	line_separator
	execute_on_all_nodes "cd ~/plescripts/oracle_preinstall && ./01_create_oracle_users.sh -release=12.2.0.1 -db_type=$db_type"
	execute_on_all_nodes "cd ~/plescripts/oracle_preinstall && ./04_apply_os_prerequis.sh -db_type=$db_type"
	LN

	line_separator
	execute_on_all_nodes "ln -s /mnt/plescripts /home/grid/plescripts"
	execute_on_all_nodes "ln -s /home/grid/plescripts/dg /home/grid/dg"
	execute_on_all_nodes "ln -s /mnt/plescripts /home/oracle/plescripts"
	execute_on_all_nodes "ln -s /home/oracle/plescripts/db /home/oracle/db"
	LN

	line_separator
	execute_on_all_nodes "~/plescripts/database_servers/add_oracle_grid_into_group_users.sh"
	LN

	line_separator
	exec_cmd "~/plescripts/disk/clear_oracle_afd_disk_headers.sh"
	exec_cmd "~/plescripts/disk/clear_oracle_afd_disk_headers.sh"
	LN

	if [ $olsnodes_ok == no ]
	then
		info "Pour un serveur standalone :"
		info "Depuis $client_hostname exécuter :"
		info "$ ~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh -remote_server=$(hostname -s)"
		LN
		info "Pour un RAC"
		info "Sur l'autre serveur exécuter : $ME -grid"
		info "Depuis $client_hostname executer :"
		info "$ ~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh -remote_server=nom_server1"
		info "$ ~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh -remote_server=nom_server2"
		info "$ ~/plescripts/ssh/setup_rac_ssh_equivalence.sh -server1=nom_server1 -server2=nom_server2"
		LN
	else
		if [ $gi_count_nodes -eq 1 ]
		then
			info "Depuis $client_hostname exécuter :"
			info "$ ~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh -remote_server=$(hostname -s)"
			LN
		else
			info "Depuis $client_hostname exécuter :"
			srv2=$(awk '{ print $1 }'<<<"$gi_node_list") # supprime l'espace de début.
			info "$ ~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh -remote_server=$(hostname -s)"
			info "$ ~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh -remote_server=$srv2"
			info "$ ~/plescripts/ssh/setup_rac_ssh_equivalence.sh -server1=$(hostname -s) -server2=$srv2"
			LN
		fi
	fi

	warning "Rebooter le ou les serveurs."
	LN
	exit 0
}

# $1 username
function exit_if_user_connected
{
	if grep -qE $1 <<<"$(who)"
	then
		error "Disconnect $1 from $(hostname -s)"
		LN
		exit 1
	fi
	if [ $gi_count_nodes -gt 1 ]
	then
		if ssh $gi_node_list "grep -qE $1 <<<\"$(who)\""
		then
			error "Disconnect $1 from $gi_node_list"
			LN
			exit 1
		fi
	fi
}

#	============================================================================
#	MAIN
#	============================================================================
script_start

typeset	-r	db_present=$(cat /etc/oratab | grep -E "^[A-Z].*")
if [ x"$db_present" != x ]
then
	error "Database active, drop database before !"
	LN
	exit 1
fi

if [ x"$action" == x ]
then
	info "$str_usage"
	LN
	exit 1
fi

if [[ $action == remove_oracle_binary && $olsnodes_ok == no ]]
then
	db_type=fs
fi

if [[ $olsnodes_ok == no && $db_type == undef ]]
then
	error "-db_type=rac|std missing."
	LN
	exit 1
else
	[ $gi_count_nodes -gt 1 ] && db_type=rac || db_type=std
fi

line_separator
info "Remove components on : $gi_current_node $gi_node_list"
LN

if [ $action == remove_grid_binary ] && su - oracle -c "test -f \$ORACLE_HOME/bin/oracle"
then
	error "oracle n'est pas désinstallé."
	LN
	exit 1
fi

confirm_or_exit "Continue"
LN

ple_enable_log -params $PARAMS
LN

exec_cmd -f -c "mount /mnt/oracle_install"
LN

case "$action" in
	remove_oracle_binary)
		deinstall_oracle
		;;

	remove_grid_binary)
		if grep -q "12.2.0.1"<<<"$GRID_HOME"
		then
			exit_if_user_connected oracle
			exit_if_user_connected grid
			deinstall_grid_12cR2
		else
			deinstall_grid_12cR1
			remove_oracleasm_disks
		fi
		;;

	*)
		warning "no action."
		LN
esac

exec_cmd -f -c "umount /mnt/oracle_install"
LN

script_stop $ME $(sed "s/srv\(.*\)0./\1/"<<<"$(hostname -s)")
