#!/bin/bash
# vim: ts=4:sw=4

[ ! -t 1 ] && PLELIB_OUTPUT=DISABLE || true
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"
typeset	-r	str_usage="Usage : $ME -start|-stop"

typeset	action=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-start)
			action=start
			typeset	listener_started=no
			shift
			;;

		-stop)
			action=stop
			typeset	listener_started=yes
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

exit_if_param_invalid action "start stop" "$str_usage"


function start_listener
{
	exec_cmd -c lsnrctl start
	[ $? -ne 0 ] && $((++count_error)) || true
	listener_started=yes # si le démarrage échoue on ne le retente pas.
	LN
}

function stop_listener
{
	ps -e|grep tnslsnr | grep -v grep >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		exec_cmd -c lsnrctl stop
		LN
	fi
	listener_started=no
}

# Avec des bases sur FS il faut monter manuellement les pooints de montage DBFS.
# Avec le grid pas de problème.
function mount_dbfs_filesystem
{
	cd /home/oracle
	typeset	-ri	nr_cfg_file=$(ls -1 *dbfs.cfg|wc -l)

	info "DBFS configuration file : #$nr_cfg_file"
	LN

	[ $nr_cfg_file -eq 0 ] && return 0 || true

	echo "Wait database 60s."
	sleep 60
	LN

	while read dbfs_cfg
	do
		pdb_name=$(cut -d_ -f1<<<"$dbfs_cfg")
		info "Cfg $dbfs_cfg, pdb name $pdb_name"
		exec_cmd -c mount /mnt/$pdb_name
	done<<<"$(ls -1 *dbfs.cfg)"
}

function start_db
{
	typeset -r OSID=$1

	ORACLE_SID=$OSID
	ORAENV_ASK=NO . oraenv
	[ $listener_started == no ] && start_listener || true
	fake_exec_cmd "sqlplus -s sys/$oracle_password as sysdba"
	sqlplus -s sys/$oracle_password as sysdba<<-EOS
	prompt startup
	startup
	EOS
	echo

	if ! command_exists crsctl
	then
		mount_dbfs_filesystem
	fi
}

function umount_dbfs_filesystem
{
	cd /home/oracle
	typeset	-ri	nr_cfg_file=$(ls -1 *dbfs.cfg|wc -l)

	info "DBFS configuration file : #$nr_cfg_file"
	LN

	[ $nr_cfg_file -eq 0 ] && return 0 || true

	while read dbfs_cfg
	do
		pdb_name=$(cut -d_ -f1<<<"$dbfs_cfg")
		info "Cfg $dbfs_cfg, pdb name $pdb_name"
		exec_cmd -c fusermount -u /mnt/$pdb_name
	done<<<"$(ls -1 *dbfs.cfg)"
}

function stop_db
{
	typeset -r OSID=$1

	ORACLE_SID=$OSID
	ORAENV_ASK=NO . oraenv

	if ! command_exists crsctl
	then
		umount_dbfs_filesystem
	fi

	[ $listener_started == yes ] && stop_listener || true
	fake_exec_cmd "sqlplus -s sys/$oracle_password as sysdba"
	sqlplus -s sys/$oracle_password as sysdba<<-EOS
	prompt shutdown immediate
	shutdown immediate
	EOS
}

typeset -i count_error=0

while IFS=':' read OSID OHOME MANAGED
do
	if [ "$MANAGED" == Y ]
	then
		info "$action database $OSID"
		[ $action == start ] && start_db $OSID || stop_db $OSID
		[ $? -ne 0 ] && $((++count_error)) || true
	else
		info "$OSID ignored."
	fi
done<<<"$(cat /etc/oratab | grep -E "^[A-Z].*")"
LN

info "$count_error $action failed."
[ $count_error -ne 0 ] && exit 1 || exit 0
