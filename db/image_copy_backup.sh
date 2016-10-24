#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME"

script_banner $ME $*

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

if [[ x"$ORACLE_SID" == x || "$ORACLE_SID" == undef ]]
then
	error "Oracle env not loaded..."
	exit 1
fi

exec_cmd cd ~/plescripts/db/rman
exec_cmd "rman target sys/$oracle_password @image_copy_level1.rman"
LN
