#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
Remove from local known_host all names and IPs not registered to the DNS.
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

typeset -i nr_valids=0
typeset -i nr_bads=0

function begin_with_number
{
	re='^[0-9]'
	[[ "$1" =~ $re ]] && return 0 || return 1
}

info "Remove duplicates"
exec_cmd "cat ~/.ssh/known_hosts | sort | uniq > /tmp/d.$$"
exec_cmd "mv /tmp/d.$$ ~/.ssh/known_hosts"
LN

typeset -r named_file_name="/var/named/named.$(hostname -d)"

while read name rem
do
	info "Readed $name"
	if $(begin_with_number $name)
	then
		info "    IP : $name"
		exec_cmd -f -ci "ssh $dns_conn \"grep \\\"\<$name\>$\\\" $named_file_name\" </dev/null >/dev/null 2>&1"
		if [ $? -ne 0 ]
		then
			((++nr_bads))
			info "    Remove $name from known_host"
			exec_cmd "sed -i '/$name/d' ~/.ssh/known_hosts"
			LN
		else
			((++nr_valids))
		fi
	else
		if grep -q "," <<<"$name"
		then
			info -n "    Extracted name : "
			name=$(cut -d, -f1<<<"$name")
			info -f "$name"
		else
			info "    Server : $name"
		fi
		exec_cmd -f -ci "ssh $dns_conn \"grep -i \\\"\<$name\>\s\\\" $named_file_name\" </dev/null >/dev/null 2>&1"
		if [ $? -ne 0 ]
		then
			((++nr_bads))
			info "    Remove $name from known_host"
			exec_cmd "sed -i '/$name/d' ~/.ssh/known_hosts"
			LN
		else
			((++nr_valids))
		fi
	fi
	LN
done<<<"$(cat ~/.ssh/known_hosts | sort)"

info "known_host :"
info "	valids  : $nr_valids"
info "	removed : $nr_bads"
