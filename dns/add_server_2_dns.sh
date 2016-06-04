#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh

. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
		-name=<name>                           Server name
		-ip=<xxx.xxx.xxx.xxx>|-ip_node=<xxx>   ip or ip node
		[-not_restart_named]                   do not restart named
"

typeset -r DOMAIN_NAME=$(hostname -d)

typeset -r named_file=/var/named/named.${DOMAIN_NAME}
typeset -r reverse_file=/var/named/reverse.${DOMAIN_NAME}

LN
exit_if_file_not_exists $named_file
exit_if_file_not_exists $reverse_file

typeset server_name=undef
typeset server_ip=undef
typeset restart_named="yes"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-name=*)
			server_name=${1##*=}
			shift
			;;

		-ip=*)
			server_ip=${1##*=}
			if [ $(grep -o "\." <<< "$server_ip" | wc -l) -ne 3 ]
			then
				error "Bad ip : $server_ip"
				error "Format : xxx.xxx.xxx.xxx"
				LN
				info "$str_usage"
				exit 1
			fi
			shift
			;;

		-ip_node=*)
			server_ip=${1##*=}
			typeset -i count_char=$(wc -m <<< "$server_ip")
			count_char=count_char-1
			if [ $count_char -lt 1 ] || [ $count_char -gt 3 ]
			then
				error "Bad ip node : $server_ip"
				error "Format : xxx (1, 2 or 3 digits)"
				LN
				info "$str_usage"
				exit 1
			fi
			server_ip=${infra_network}.$server_ip
			shift
			;;

		-not_restart_named)
			restart_named="no"
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

exit_if_param_undef server_name	"$str_usage"
exit_if_param_undef server_ip	"$str_usage"

typeset -r ip_node=${server_ip##*.}

grep "^\b$server_name .* $server_ip" $named_file
if [ $? -eq 0 ]
then
	info "$server_name / $server_ip already registered, nothing to do."
	exit 0
fi

info "Update $named_file"
exec_cmd "printf \"%-19s IN A  %s\n\" $server_name $server_ip >> $named_file"
LN

info "Update $reverse_file"
exec_cmd "printf \"%-3s IN PTR  %s.%s.\n\" $ip_node $server_name $DOMAIN_NAME >> $reverse_file"
LN

if [ "$restart_named" = "yes" ]
then
	info "Restart named"
	exec_cmd "systemctl restart named.service"
fi
