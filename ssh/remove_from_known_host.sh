#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -host=<hostname> |& -ip=<ip_addr>
	-host : remove 'hostname' from ~/.ssh/know_hosts
	-ip   : remove 'ip_addr' from ~/.ssh/know_hosts
"

script_banner $ME $*

typeset host=undef
typeset ip=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-host=*)
			host=${1##*=}
			shift
			;;

		-ip=*)
			ip=${1##*=}
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

[[ "$host" == undef && "$ip" == undef ]] && error "Arg missing." && exit 1 || true

[ "$host" != undef ] && remove_from_known_hosts "$host"

[ "$ip" != undef ] && remove_ip_from_known_hosts "$ip"

#	Nettoyage des lignes vides, mais ne devrait plus arriver.
[ -f ~/.ssh/known_hosts ] && exec_cmd sed -i '/^$/d' ~/.ssh/known_hosts

exit 0
