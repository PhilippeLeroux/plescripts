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

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

# Test même si le crs est utilisé, pour rester homogène dans les scripts et
# éviter des régressions sur les bases sur FS lors de modifications des scripts.
exit_if_ORACLE_SID_not_defined

if command_exists crsctl
then
	while read dbname
	do
		[ x"$dbname" == x ] && continue || true

		# Ajout de l'option -force à cause de DBFS, s'il est utilisé dans un PDB
		# alors il empêche la fermeture d'une base sur un cluser RAC.
		exec_cmd "srvctl stop database -db $dbname -force"
		LN
	done<<<"$(srvctl config database)"
else
	sqlplus_cmd "$(set_sql_cmd "shutdown immediate")"
	LN
fi
