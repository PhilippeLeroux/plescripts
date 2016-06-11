#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	Supprime les comptes oracle & grid ainsi que tous les groups"

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOOP
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

line_separator
info "delete users oracle & grid"
exec_cmd -c userdel -r oracle
exec_cmd -c userdel -r grid
LN

line_separator
info "delete all groups"
exec_cmd -c groupdel oinstall
exec_cmd -c groupdel dba
exec_cmd -c groupdel oper
exec_cmd -c groupdel asmadmin
exec_cmd -c groupdel asmdba
exec_cmd -c groupdel asmoper
LN
