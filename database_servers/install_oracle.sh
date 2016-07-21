#!/bin/bash

#	ts=4 sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=<str>        Identifiant.
	-action=install  Si config l'installation n'est pas lancée.
"

info "$ME $@"

typeset db=undef
typeset action=install

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-action=*)
			action=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			rm -f $PLELIB_LOG_FILE
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info $str_usage
			exit 1
			;;
	esac
done

exit_if_param_undef		db						"$str_usage"
exit_if_param_invalid	action "install config" "$str_usage"

#	Répertoire contenant le fichiers de configuration de la db
typeset -r dir_files=~/plescripts/database_servers/$db
[ ! -d $dir_files ]	&& error "$dir_files not exists." && exit 1

#	Nom du "fichier réponse" pour l'installation d'oracle
typeset -r rsp_file=${dir_files}/oracle_$db.rsp

#
typeset -a	node_names
typeset -a	node_ips
typeset -a	node_vip_names
typeset -a	node_vips
typeset -a	node_priv_names
typeset -a	node_priv_ips
typeset -i	max_nodes=0

function load_node_cfg # $1 node_file $2 idx
{
	typeset -r	file=$1
	typeset -ri	idx=$2

	info "Load node $(( $idx + 1 )) from $file"
	exit_if_file_not_exists $file
	while IFS=':' read db_type node_name node_ip node_vip_name node_vip node_priv_name node_priv_ip rem
	do
		if [ x"$clusterNodes" = x ]
		then
			clusterNodes=$node_name:$node_vip_name
		else
			clusterNodes=$clusterNodes,$node_name:$node_vip_name
		fi
		node_names[$idx]=$node_name
		node_ips[$idx]=$node_ip
		node_vip_names[$idx]=$node_vip_name
		node_vips[$idx]=$node_vip
		node_priv_names[$idx]=$node_priv_name
		node_priv_ips[$idx]=$node_priv_ip
	done < $file
	info "Server name is ${node_names[$idx]}"
	LN
}

function create_response_file
{
	line_separator
	info "Création du fichier réponse pour l'installation d'oracle"
	exec_cmd cp -f template_oracle.rsp $rsp_file
	LN

	update_value oracle.install.option				INSTALL_DB_SWONLY					$rsp_file
	update_value ORACLE_HOSTNAME					${node_names[0]}					$rsp_file
	update_value UNIX_GROUP_NAME					oinstall							$rsp_file
	update_value INVENTORY_LOCATION					/u01/app/oraInventory				$rsp_file
	update_value ORACLE_HOME						/u01/app/oracle/$oracle_release/dbhome_1	$rsp_file
	update_value ORACLE_BASE						/u01/app/oracle						$rsp_file
	update_value oracle.install.db.CLUSTER_NODES	empty								$rsp_file
	update_value oracle.install.db.InstallEdition	EE									$rsp_file
	update_value oracle.install.db.DBA_GROUP		dba									$rsp_file
	update_value oracle.install.db.OPER_GROUP		oper								$rsp_file
	update_value oracle.install.db.BACKUPDBA_GROUP	dba									$rsp_file
	update_value oracle.install.db.DGDBA_GROUP		dba									$rsp_file
	update_value oracle.install.db.KMDBA_GROUP		dba									$rsp_file

	if [ $max_nodes -gt 1 ]
	then
		server_list=${node_names[0]}
		for inode in $( seq 1 $(( $max_nodes - 1 )) )
		do
			server_list=$server_list","${node_names[$inode]}
		done
		update_value oracle.install.db.CLUSTER_NODES "$server_list" $rsp_file
	fi

	LN
}

function copy_response_file
{
	line_separator
	info "Copie du fichier réponse sur le noeud ${node_names[0]}:/home/oracle/"
	exec_cmd "scp $rsp_file $prop_file oracle@${node_names[0]}:/home/oracle/"
	LN
}

function prepare_installation_directory
{
	line_separator
	info "Montage du répertoire d'installation."
	exec_cmd -cont "ssh root@${node_names[0]} mount /mnt/oracle_install"
	LN
}

function start_oracle_installation
{
	line_separator
	info "Démarre l'installation d'oracle, attente ~35mn"
	info "Log disponible ici : /u01/app/oraInventory/logs"
	exec_cmd -c "ssh oracle@${node_names[0]} \"LANG=C /mnt/oracle_install/database/runInstaller -silent -showProgress -waitforcompletion -responseFile /home/oracle/oracle_$db.rsp\""
	LN
}

function run_post_install_root_scripts_on_node	# $1 No node
{
	typeset  -ri inode=$1
	[ $# -eq 0 ] && error "$0 <node number>" && exit 1

	line_separator
	exec_cmd "ssh -t -t root@${node_names[$inode]} \"LANG=C /u01/app/oracle/$oracle_release/dbhome_1/root.sh\" </dev/null"
	LN
}

function launch_memstat
{
	typeset mode="-h"
	[ "$DEBUG_PLE" = yes ] && mode=""

	for i in $( seq 0 $(( max_nodes - 1 )) )
	do
		exec_cmd $mode -c "ssh -n oracle@${node_names[$i]} \
		 \"nohup ~/plescripts/memory/memstats.sh -title=install_oracle >/dev/null 2>&1 &\""
	done
}

function on_exit
{
	[ "$INSTALL_GRAPH" != YES ] && return 0

	typeset mode="-h"
	[ "$DEBUG_PLE" = yes ] && mode=""

	for i in $( seq 0 $(( max_nodes - 1 )) )
	do
		exec_cmd $mode -c "ssh -t oracle@${node_names[$i]} \
		\"~/plescripts/memory/memstats.sh -kill -title=install_oracle >/dev/null 2>&1\""
	done
}

trap on_exit EXIT

#	============================================================================
#	MAIN
#	============================================================================
typeset -r script_start_at=$SECONDS

line_separator
for file in $dir_files/node*
do
	load_node_cfg $file $max_nodes
	max_nodes=max_nodes+1
done

info "Total nodes #${max_nodes}"
if [ $max_nodes -gt 1 ]
then
	info "==> clusterNodes  = $clusterNodes"
fi
LN

[ "$INSTALL_GRAPH" == YES ] && launch_memstat

create_response_file

if [ $action == install ]
then
	copy_response_file

	prepare_installation_directory

	start_oracle_installation

	typeset -i inode=0
	while [ $inode -lt $max_nodes ]
	do
		run_post_install_root_scripts_on_node $inode
		inode=inode+1
		LN
	done

	typeset -r type_disks=$(cat ~/plescripts/database_servers/$db/disks | tail -1 | cut -d: -f1)
	[ "$type_disks" == FS ] && exec_cmd "ssh -t root@${node_names[0]} \"~/plescripts/db/create_systemd_service_oracledb.sh\""

	info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
	LN

	info "Database can be created."
fi
