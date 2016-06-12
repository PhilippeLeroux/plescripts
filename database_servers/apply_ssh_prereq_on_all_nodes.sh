#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=<str>"

info "$ME $@"

typeset db=undef

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

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef db	"$str_usage"

typeset -r cfg_path=~/plescripts/database_servers/$db
exit_if_dir_not_exists $cfg_path "$str_usage"

typeset -ri count_nodes=$(ls -1 $cfg_path/node* | wc -l)

typeset -a node_list

#	Charge le nom de tous les noeuds.
for inode in $( seq 1 $count_nodes )
do
	typeset -i i=inode-1
	node_list[$i]=$( cat $cfg_path/node${inode} | cut -d':' -f2 )
done

warning "You need to enter ${count_nodes} times root password."
info "Press a key to continue."
read keyboard

#	Fait la configuration ssh
for il in $( seq 0 $(( $count_nodes - 1 )) )
do
	line_separator
	on_server=${node_list[$il]}
	for ir in $( seq 0 $(( $count_nodes - 1 )) )
	do
		remote_server=${node_list[$ir]}
		if [ "$on_server" != "$remote_server" ]
		then
			info "Setup ssh from $on_server to $remote_server"
			exec_cmd "ssh -t root@$on_server \"~/plescripts/ssh/ssh_equi_cluster_rac.sh -remote_server=$remote_server\""
			LN
		fi
	done
done
LN

