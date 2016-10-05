# vim: ts=4:sw=4

typeset -r cfg_path_prefix=~/plescripts/database_servers

#*> $1 db
#*> return max nodes.
function cfg_max_nodes
{
	typeset -r db=$(to_lower $1)

	if [ ! -d $cfg_path_prefix/$db ]
	then
		error "not exist $cfg_path_prefix/$db"
		exit 1
	fi

	ls -1 $cfg_path_prefix/$db/node*|wc -l
}

#*> $1 db
#*> $2 #node 
#*> Init variables :
#*>		- cfg_db_type			std ou rac
#*>		- cfg_server_name		nom du serveur
#*>		- cfg_server_ip			ip du serveur
#*>		- cfg_server_vip		vip du serveur
#*>		- cfg_iscsi_ip			ip des disques iscsi
#*>		- cfg_luns_hosted_by	vbox|san
function cfg_load_node_info 
{
	typeset -r	db=$(to_lower $1)
	typeset -ri nr_node=$2
	typeset -r	cfg_file=$cfg_path_prefix/$db/node${nr_node}

	if [ ! -f $cfg_file ]
	then
		error "not exist : $cfg_file"
		exit 1
	fi

	#	cfg_uX champs non utilisés
	IFS=: read	cfg_db_type cfg_server_name cfg_server_ip cfg_u1 cfg_server_vip	\
				cfg_u2 cfg_iscsi_ip cfg_luns_hosted_by							\
		<$cfg_file
}
