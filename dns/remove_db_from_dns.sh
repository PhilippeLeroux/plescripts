#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage="Usage : $ME -db=<>"

typeset		db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
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

exit_if_param_undef db	$str_usage

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

for (( inode=1; inode <= max_nodes; ++inode ))
do
	cfg_load_node_info $db $inode
	exec_cmd ~/plescripts/dns/remove_server.sh -name=$cfg_server_name -no_restart
	[ $max_nodes -gt 1 ] && exec_cmd ~/plescripts/dns/remove_server.sh -name=$cfg_server_name-vip -no_restart
	LN
done

if [ -f $cfg_path_prefix/$db/scanvips ]
then
	typeset	-r	DOMAIN_NAME=$(hostname -d)
	typeset	-r	named_file=/var/named/named.${DOMAIN_NAME}

	IFS=':' read scan_name vip1 vip2 vip3<<<$(cat $cfg_path_prefix/$db/scanvips)

	exec_cmd ~/plescripts/dns/remove_server.sh -name=$scan_name -no_restart
	LN

	# Depuis l'utilisation de DHCP le non de la SCAN n'est présent qu'une fois
	# il y a donc 2 IP qui ne sont pas effacées par le script remove_server.sh.
	exec_cmd "sed -i '/${vip1}/d' $named_file"
	exec_cmd "sed -i '/${vip2}/d' $named_file"
	exec_cmd "sed -i '/${vip3}/d' $named_file"
	LN
fi

info "Restart named & dhcpd"
exec_cmd "systemctl restart named.service"
exec_cmd "systemctl restart dhcpd.service"
LN
