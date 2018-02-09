#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
L'environnement de la base doit être chargé
"

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

exit_if_ORACLE_SID_not_defined

typeset	-i	nr_stby=0

while read dbname dash role rem
do
	case "$role" in
		"Primary")
			primary=$dbname
			;;
		"Physical"|"Snapshot")
			((++nr_stby))
			standby_list="$standby_list$dbname "
			;;
		*)	error "No dataguard configuration."
			exit 1
	esac
done<<<"$(dgmgrl -silent -echo sys/$oracle_password "show configuration" |\
			grep -E "Primary|Physical|Snapshot")"

info "Primary $primary"
fake_exec_cmd "dgmgrl -silent -echo sys/$oracle_password<<EO_CMD"
dgmgrl -silent -echo sys/$oracle_password<<EO_CMD
show configuration
show database $primary
validate database $primary
EO_CMD
LN

info "$nr_stby physical database(s)"
LN

for standby in $standby_list
do
	line_separator
	info "Physical $standby"
	fake_exec_cmd "dgmgrl -silent -echo sys/$oracle_password<<EO_CMD"
	dgmgrl -silent -echo sys/$oracle_password<<-EO_CMD
	show database $standby
	validate database $standby
	EO_CMD
	LN
done
