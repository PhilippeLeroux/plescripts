#!/bin/bash

# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=<str>        Identifiant.
	-action=install  Si config l'installation n'est pas lancée.
"

info "Running : $ME $*"

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
	exit_if_file_not_exist $file
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
	info "Create response file for the Oracle software."
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
	info "Copy response file to ${node_names[0]}:/home/oracle/"
	exec_cmd "scp $rsp_file $prop_file oracle@${node_names[0]}:/home/oracle/"
	LN
}

function mount_install_directory
{
	line_separator
	info "Mount install directory :"
	exec_cmd -cont "ssh root@${node_names[0]} mount /mnt/oracle_install"
	LN
}

function start_oracle_installation
{
	line_separator
	info "Start Oracle installation (~35mn)"
	info "Log here : /u01/app/oraInventory/logs"
	exec_cmd -c "ssh oracle@${node_names[0]} \"LANG=C /mnt/oracle_install/database/runInstaller -silent -showProgress -waitforcompletion -responseFile /home/oracle/oracle_$db.rsp\""
	LN
}

function run_post_install_root_scripts_on_node	# $1 No node
{
	typeset  -ri inode=$1
	[ $# -eq 0 ] && error "$0 <node number>" && exit 1

	typeset -r script_root_sh="/u01/app/oracle/$oracle_release/dbhome_1/root.sh"
	typeset -r backup_script_root_sh="/home/oracle/root.sh.backup_install"
	line_separator
	exec_cmd "ssh -t -t root@${node_names[$inode]} \"LANG=C $script_root_sh\" </dev/null"
	LN

	# Je viens de découvrir ça :
	# 8.3.1 Creating a Backup of the root.sh Script
	info "Backup the root.sh script to $backup_script_root_sh"
	LN
}

#	============================================================================
#	MAIN
#	============================================================================
script_start

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

create_response_file

[ $action == config ] && exit 0	# Pas d'installation.

~/plescripts/shell/wait_server ${node_names[0]}

stats_tt start oracle_installation

copy_response_file

mount_install_directory

start_oracle_installation

typeset -i inode=0
while [ $inode -lt $max_nodes ]
do
	run_post_install_root_scripts_on_node $inode
	inode=inode+1
	LN
done

typeset -r type_disks=$(cat ~/plescripts/database_servers/$db/disks | tail -1 | cut -d: -f1)
[ "$type_disks" == FS ] && exec_cmd "ssh -t root@${node_names[0]} \"~/plescripts/database_servers/create_systemd_service_oracledb.sh\""

stats_tt stop oracle_installation

script_stop $ME
LN

line_separator
info "Database can be created :"
LN
info "$ ssh oracle@${node_names[0]}"
info "oracle@${node_names[0]}:NOSID:oracle> cd db"
info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db"
if [ $max_nodes -gt 1 ]
then
	info "or"
	info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db -policyManaged"
	info "or"
	info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db -db_type=RACONENODE"
fi
