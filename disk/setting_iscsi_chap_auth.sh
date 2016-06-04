#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh

EXEC_CMD_ACTION=EXEC

. ~/plescripts/global.cfg

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -user=<> -password=<>"

typeset user=undef
typeset password=undef


while [ $# -ne 0 ]
do
	case $1 in
		-user=*)
			user=${1##*=}
			shift
			;;

		-password=*)
			password=${1##*=}
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

exit_if_param_undef user		"$str_usage"
exit_if_param_undef password	"$str_usage"

typeset -r iscsid_conf=/etc/iscsi/iscsid.conf

info "Se script ne fonctionnera qu'une seule fois !"
exec_cmd "sed -i 's/^#node.session.auth.authmethod = CHAP/node.session.auth.authmethod = CHAP/' $iscsid_conf"
exec_cmd "sed -i 's/^#node.session.auth.username_in = username.*/node.session.auth.username_in = ${user}/' $iscsid_conf"
exec_cmd "sed -i 's/^#node.session.auth.password_in = password.*/node.session.auth.password_in = ${password}/' $iscsid_conf"

