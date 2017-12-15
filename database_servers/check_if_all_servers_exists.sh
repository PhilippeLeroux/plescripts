#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/vmlib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

#	Si define_new_server.sh est appelé 2 fois de suite l'adresses IP du second
#	serveur sera la même que pour le premier.
#	Il est donc impératif que le serveur soit créé car son adresse IP sera
#	enregistrée dans le DNS.

typeset	-r	str_usage=\
"Usage :
$ME

exit 0 if all servers exists, else exit 1."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

#ple_enable_log -params $PARAMS

typeset	all_vms_created=yes
while read fullpath
do
	[ x"$fullpath" == x ] && continue || true
	db=${fullpath##*/}
	typeset	-i	max_nodes=$(cfg_max_nodes $db)
	for (( node = 1; node <= max_nodes; ++node ))
	do
		cfg_load_node_info $db $node
		if ! vm_exists $cfg_server_name
		then
			all_vms_created=no
			error "$db : $cfg_server_name not exists."
			LN
		fi
	done
done<<<"$(find ~/plescripts/database_servers/* -type d)"

if [ $all_vms_created == yes ]
then
	exit 0
else
	error "All servers must have created before defining new ones."
	LN
	exit 1
fi
