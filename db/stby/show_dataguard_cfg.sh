#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
L'environnement de la base doit être chargé
"

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

exit_if_ORACLE_SID_not_defined

function exec_dgmgrl
{
	typeset -r cmd="$@"
	fake_exec_cmd "dgmgrl -silent sys/$oracle_password"
dgmgrl -silent -echo sys/$oracle_password<<EOS
$cmd
EOS
}

while read dbname dash role rem
do
	case "$role" in
		"Primary")	primary=$dbname ;;
		"Physical")	standby_list="$standby_list$dbname ";;
		*)	error "Cannot check database"
			exit 1
	esac
done<<<"$(dgmgrl -silent -echo sys/Oracle12 "show configuration" |\
			grep -E "Primary|Physical")"

line_separator
exec_dgmgrl "show configuration"

line_separator
info "Primary $primary"
exec_dgmgrl "show database $primary"
exec_dgmgrl "validate database $primary"

for standby in $standby_list
do
	line_separator
	info "Standby $standby"
	exec_dgmgrl "show database $standby"
	exec_dgmgrl "validate database $standby"
done
