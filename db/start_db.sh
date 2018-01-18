#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME"

typeset oracle_sid=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-oracle_sid=*)
			oracle_sid=${1##*=}
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

#ple_enable_log -params $PARAMS

if command_exists crsctl
then
	typeset	-r	crs_used=yes
else
	typeset	-r	crs_used=no
fi

if [ "$oracle_sid" == undef ]
then
	[ $crs_used == no ] && exit_if_ORACLE_SID_not_defined || true
else
	export ORACLE_SID=$oracle_sid
	ORAENV_ASK=NO . oraenv
fi

typeset	-r	instance=$ORACLE_SID

if [ $crs_used == yes ]
then
	typeset -r	db_name=$(srvctl config database)

	exec_cmd srvctl start database -db $db_name
	LN

	if [[ x"$ORACLE_SID" == x || "$ORACLE_SID" == NOSID ]]
	then # Pour que le script lspdbs fonctionne.
		export ORACLE_SID=$(~/plescripts/db/get_active_instance.sh)
		info "Load Oracle environment for $ORACLE_SID"
		ORAENV_ASK=NO . oraenv
		LN
	fi
else
	sqlplus_cmd "$(set_sql_cmd "startup")"
	LN
fi

typeset		warning_msg
if [[ x"$ORACLE_SID" != x && "$ORACLE_SID" != NOSID && x"$instance" != x && "$instance" != NOSID ]]
then
	ORACLE_SID=$(~/plescripts/db/get_active_instance.sh)
	# Dans le cas d'un RAC Policy Managed l'instance peut changer.
	if [[ "$instance" != "$ORACLE_SID" ]]
	then
		warning_msg="${BLINK}Instance${NORM} has been changed $ORACLE_SID became $instance"
		# Permet au script lspdbs de fonctionner.
		export ORACLE_SID=$instance
		ORAENV_ASK=NO . oraenv
	fi
fi

sqlplus_cmd "$(set_sql_cmd "@$HOME/plescripts/db/sql/lspdbs.sql")"
LN

if [ x"$warning_msg" != x ]
then
	warning "$warning_msg"
	LN
fi
