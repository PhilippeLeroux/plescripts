#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-name=<str>]
	Si name = auto ou est omis alors utilise le nom du serveur.
"

script_banner $ME $*

typeset name=${1-auto}

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-name=*)
			name=${1##*=}
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

[ "$name" == auto ] && name=$(hostname -s) || true

line_separator
[ ${name:0:3} == srv ] && name=$(initcap "$(echo $name | sed 's/...\(.*\)\(..\)/\1 \2/')")
exec_cmd "figlet -c \"$name\" > /tmp/ascii"
LN

line_separator
exec_cmd "cat /tmp/ascii ~/plescripts/gadgets/login.ascii > /etc/motd"
exec_cmd "echo \"\S\" > /etc/issue"
exec_cmd "echo \"Kernel \r on an \m\" >> /etc/issue"
exec_cmd "cat /tmp/ascii ~/plescripts/gadgets/login.ascii >> /etc/issue"
exec_cmd "echo \"\S\" > /etc/issue.net"
exec_cmd "echo \"Kernel \r on an \m\" >> /etc/issue.net"
exec_cmd "cat /tmp/ascii ~/plescripts/gadgets/login.ascii >> /etc/issue.net"
LN

exec_cmd -c rm /tmp/ascii
LN
