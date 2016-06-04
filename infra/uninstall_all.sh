#!/bin/sh

#	ts=4	sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-databases    : supprime les bases de données.
	[!] -oracle   : supprime le binaire oracle.
	[!] -grid     : supprime le binaire grid.

	-all          : tous les flags sont combinées.
	    Ajouter :
	    ! -oracle si le binaire oracle n'est pas installé
	    ! -grid si le GI n'est pas installé, seul les disques seront supprimés

	L'utilisation normale est d'utiliser -all, les autres options ne servent
	que s'il y a un plantage avec -all

	Seul root peut exécuter ce script et il doit être exécuté sur le serveur
	concerné.
"

info "$ME $@"

typeset action
typeset neg=no

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
			neg=yes
			shift
			;;

		-emul)
			exit_if_yes $neg -emul
			EXEC_CMD_ACTION=NOP
			arg1="-emul"
			shift
			;;

		-all)
			exit_if_yes $neg -all
			action="delete_databases remove_oracle_binary remove_grid_binary"
			shift
			;;

		-databases)
			exit_if_yes $neg -databases
			action="$action delete_databases"
			shift
			;;

		-oracle)
			if [ $neg = yes ]
			then
				neg=no
				action=$(sed "s/ remove_oracle_binary//"<<<"$action")
			else
				action="$action remove_oracle_binary"
			fi
			shift
			;;

		-grid)
			if [ $neg = yes ]
			then
				neg=no
				action=$(sed "s/ remove_grid_binary//"<<<"$action")
				action="$action remove_disks"
			else
				action="$action remove_grid_binary"
			fi
			shift
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

[ x"$action" = x ] && info "$str_usage" && exit 1

function suoracle
{
	[ "$1" = -f ] && arg=$1 && shift

	exec_cmd $arg "su - oracle -c \"$@\""
}

function sugrid
{
	[ "$1" = -c ] && arg=$1 && shift

	exec_cmd $arg "su - grid -c \"$@\""
}

function delete_all_db
{
	line_separator
	info "delete all DB :"
	cat /etc/oratab | grep -E "^[A-Z]" |\
	while IFS=':' read OSID REM
	do
		suoracle "~/plescripts/db/delete_db.sh -db=$OSID"
	done
	LN
}

function deinstall_oracle
{
	line_separator
	info "deinstall oracle"
	suoracle -f "~/plescripts/infra/uninstall_oracle.sh $arg1"
	LN
}

function remove_disks
{
	exec_cmd "~/plescripts/disk/clear_oracle_disk_headers.sh -doit"
	exec_cmd -c "~/plescripts/disk/logout_sessions.sh"
}

function deinstall_grid
{
	line_separator
	info "deinstall GI"
	sugrid -c "crsctl stop has"
	sugrid -c "crsctl disable has"
	remove_disks
	sugrid "/mnt/oracle_install/grid/runInstaller -deinstall -home \\\$ORACLE_HOME"
	exec_cmd "rm -fr /etc/oraInst.loc"
	exec_cmd "rm -fr /opt/ORCLfmap"
	exec_cmd "rm -fr /etc/oratab"
	exec_cmd "rm -fr /u01/app/grid/log"
	LN
}

exec_cmd -f -c "mount /mnt/oracle_install"
LN

if grep -q delete_databases <<< "$action"
then
	delete_all_db
fi

if grep -q remove_oracle_binary <<< "$action"
then
	deinstall_oracle
fi

if grep -q remove_grid_binary <<< "$action"
then
	deinstall_grid
elif grep -q remove_disks <<< "$action"
then
	remove_disks
fi

exec_cmd -f -c "umount /mnt/oracle_install"
LN

info "Éventuellement faire un rm -rf /tmp/* en root"
LN
info "Exécuter revert_to_master.sh sur ce serveur."
info "Puis delete_infra.sh depuis le client."
LN
