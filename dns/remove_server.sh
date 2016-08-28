#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh

. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r str_usage="Usage : $ME -name=<> -no_restart"

typeset -r DOMAIN_NAME=$(hostname -d)

typeset -r named_file=/var/named/named.${DOMAIN_NAME}
typeset -r reverse_file=/var/named/reverse.${DOMAIN_NAME}

LN
exit_if_file_not_exists $named_file
exit_if_file_not_exists $reverse_file

typeset name=undef
typeset restart=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-name=*)
			name=${1##*=}
			shift
			;;

		-no_restart)
			restart=no
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info $str_usage
			exit 1
			;;
	esac
done

exit_if_param_undef name	$str_usage

IFS='.' read server_name server_domain<<<$(echo $name)

exec_cmd "sed -i '/${server_name} /d' $named_file"
LN

exec_cmd "sed -i '/${server_name}.orcl/d' $reverse_file"
LN

if [ $restart = yes ]
then
	info "Restart named"
	exec_cmd "systemctl restart named.service"
	LN
fi
