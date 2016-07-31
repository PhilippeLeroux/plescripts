#!/bin/bash

#	ts=4	sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=<str> [-delete_vms]"

info "$ME $@"

typeset	db=undef
typeset	delete_vms=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-delete_vms)
			delete_vms=yes
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

exit_if_param_undef db	"$str_usage"

typeset -r upper_db=$(to_upper $db)

typeset -r cfg_path=~/plescripts/database_servers/$db

if [ -d $cfg_path ]
then
	if [ $delete_vms == yes ]
	then
		line_separator
		exec_cmd -c "~/plescripts/shell/delete_vm -db=$db"
		LN
	fi
		
	typeset -ri count_nodes=$(ls -1 $cfg_path/node* | wc -l)

	line_separator
	for inode in $( seq 1 $count_nodes )
	do
		node_name=$( cat $cfg_path/node$inode | cut -d':' -f2 )
		info "Supprime $node_name du fichier .ssh/known_hosts"
		remove_from_known_hosts $node_name
		LN
	done

	line_separator
	info "Mise à jour du dns :"
	exec_cmd "ssh -t $dns_conn \"~/plescripts/dns/remove_db_from_dns.sh -db=$db\""
	LN

	line_separator
	info "Mise à jour du san :"
	exec_cmd "ssh -t $san_conn \"~/plescripts/san/reset_all_for_db.sh -db=$db\""
	LN
else
	warning "No servers for $db"
	exit 1
fi

line_separator
info "Remove $cfg_path"
exec_cmd -c "rm -rf $cfg_path"
LN
