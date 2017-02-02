# vim: ts=4:sw=4

typeset -r cfg_path_prefix=~/plescripts/database_servers

#*> $1 db
#*> $2 use_return_code : return 1 instead of exit 1
function cfg_exists
{
	info -n "Configuration for $1 exist : "
	if [ ! -d $cfg_path_prefix/$(to_lower $1) ]
	then
		info -f "[$KO]"
		LN
		[ "$2" == use_return_code ] && return 1 || exit 1
	fi
	info -f "[$OK]"
	LN
}

#*> $1 db
#*> return max nodes.
function cfg_max_nodes
{
	typeset -r db=$(to_lower $1)

	ls -1 $cfg_path_prefix/$db/node*|wc -l
}

#*> $1 db
#*> $2 #node
#*> Init variables :
#*>		- cfg_db_type			std ou rac
#*>		- cfg_server_name		nom du serveur
#*>		- cfg_server_ip			ip du serveur
#*>		- cfg_server_vip		vip du serveur
#*>		- cfg_rac_network		rac interco
#*>		- cfg_iscsi_ip			ip des disques iscsi
#*>		- cfg_luns_hosted_by	vbox|san
#*>		- cfg_oracle_home		ocfs2|xfs
#*>		- cfg_stantby			standby id
#*>
#*> La fonction test_if_other_nodes_up du script clone_master.sh lie le nom
#*> des serveurs sans passer pas cette fonction : ne pas déplacer le champs
#*> contenant le nom de la fonction.
function cfg_load_node_info
{
	typeset -r	db=$(to_lower $1)
	typeset -ri nr_node=$2
	typeset -r	cfg_file=$cfg_path_prefix/$db/node${nr_node}

	IFS=: read	cfg_db_type										\
				cfg_server_name cfg_server_ip cfg_server_vip	\
				cfg_rac_network cfg_iscsi_ip					\
				cfg_luns_hosted_by								\
				cfg_oracle_home									\
				cfg_standby										\
		<$cfg_file
}

#*> $1 db
#*> return total disk size (Gb)
function cfg_total_disk_size_gb
{
	typeset -r	l_db=$(to_lower $1)
	typeset	-i	l_total_size_gb=0

	while IFS=: read dg_name size_gb first_no last_no
	do
		count=$(( $last_no - $first_no + 1 ))
		l_total_size_gb=$(( l_total_size_gb + size_gb * count ))
	done < $cfg_path_prefix/$db/disks

	echo $l_total_size_gb
}
