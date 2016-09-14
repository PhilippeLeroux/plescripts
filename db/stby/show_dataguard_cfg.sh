#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
L'environnement de la base doit être chargé
"

info "Running : $ME $*"

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

if [[ x"$ORACLE_SID" == x || "$ORACLE_SID" == NOSID ]]
then
	error "ORACLE_SID not defined."
	exit 1
fi

while read dbname dash role rem
do
	case "$role" in
		"Primary")	primary=$dbname ;;
		"Physical")	standby=$dbname;;
		*)	error "Cannot check database"
			exit 1
	esac
done<<<"$(dgmgrl -silent -echo sys/Oracle12 "show configuration" |\
			grep -E "Primary|Physical")"

line_separator
exec_cmd "dgmgrl -silent -echo sys/$oracle_password 'show configuration'"

line_separator
exec_cmd "dgmgrl -silent -echo sys/$oracle_password 'show database $primary'"
exec_cmd "dgmgrl -silent -echo sys/$oracle_password 'validate database $primary'"

line_separator
exec_cmd "dgmgrl -silent -echo sys/$oracle_password 'show database $standby'"
exec_cmd "dgmgrl -silent -echo sys/$oracle_password 'validate database $standby'"
