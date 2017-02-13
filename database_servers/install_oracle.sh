#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name         Identifiant.
	-action=install  Si config l'installation n'est pas lancée.
"

script_banner $ME $*

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
			db=$(to_lower ${1##*=})
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
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef		db						"$str_usage"
exit_if_param_invalid	action "install config" "$str_usage"

cfg_exists $db
#	Répertoire contenant le fichiers de configuration de la db
typeset -r db_cfg_path=$cfg_path_prefix/$db

#	Nom du "fichier réponse" pour l'installation d'oracle
typeset -r rsp_file=${db_cfg_path}/oracle_$db.rsp

#
typeset -a	node_names
typeset -a	node_ips
typeset -a	node_vip_names
typeset -a	node_vips
typeset -a	node_priv_names
typeset -a	node_priv_ips
typeset -ri	max_nodes=$(cfg_max_nodes $db)

typeset		primary_db_server=none

function load_node_cfg # $1 inode
{
	typeset	-ri	inode=$1

	info "Load node #${inode}"
	cfg_load_node_info $db $inode

	if [[ $inode -eq $max_nodes && $cfg_standby != none ]]
	then
		if [ -d $cfg_path_prefix/$cfg_standby ]
		then # La config exist, donc sur ce serveur créer une standby
			primary_db_server=$cfg_standby
		fi
	fi

	if [ x"$clusterNodes" = x ]
	then
		clusterNodes=$cfg_server_name:${cfg_server_name}-vip
	else
		clusterNodes=$clusterNodes,$cfg_server_name:${cfg_server_name}-vip
	fi

	node_names+=( $cfg_server_name )
	node_ips+=( $cfg_server_ip )
	node_vip_names+=( ${cfg_server_name}-vip )
	node_vips+=( $cfg_server_vip )
	node_iscsi_names+=( ${cfg_server_vip}-priv )
	node_iscsi_ips+=( $cfg_iscsi_ip )

	info "Server name is ${cfg_server_name}"
	LN
}

function create_response_file
{
	line_separator
	info "Create response file for Oracle software."
	exit_if_file_not_exists template_oracle_${oracle_release%.*.*}.rsp
	exec_cmd cp -f template_oracle_${oracle_release%.*.*}.rsp $rsp_file
	LN

	typeset	-r	O_BASE=/$ORCL_DISK/app/oracle
	typeset	-r	O_HOME=$O_BASE/$oracle_release/dbhome_1

	update_value oracle.install.option				INSTALL_DB_SWONLY	$rsp_file
	update_value ORACLE_HOSTNAME					${node_names[0]}	$rsp_file
	update_value UNIX_GROUP_NAME					oinstall			$rsp_file
	update_value INVENTORY_LOCATION					$ORA_INVENTORY		$rsp_file
	update_value ORACLE_HOME						$O_HOME				$rsp_file
	update_value ORACLE_BASE						$O_BASE				$rsp_file
	update_value oracle.install.db.CLUSTER_NODES	empty				$rsp_file
	update_value oracle.install.db.InstallEdition	EE					$rsp_file
	update_value oracle.install.db.DBA_GROUP		dba					$rsp_file
	update_value oracle.install.db.OPER_GROUP		oper				$rsp_file
	update_value oracle.install.db.BACKUPDBA_GROUP	dba					$rsp_file
	update_value oracle.install.db.DGDBA_GROUP		dba					$rsp_file
	update_value oracle.install.db.KMDBA_GROUP		dba					$rsp_file

	if [ $max_nodes -gt 1 ]
	then
		server_list=${node_names[0]}
		for (( inode=1; inode < max_nodes; ++inode ))
		do
			server_list=$server_list","${node_names[inode]}
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
	info "Start Oracle installation (~30mn)"
	info "Logs : $ORA_INVENTORY/logs"
	add_dynamic_cmd_param "\"LANG=C /mnt/oracle_install/database/runInstaller"
	add_dynamic_cmd_param "      -silent"
	add_dynamic_cmd_param "      -showProgress"
	add_dynamic_cmd_param "      -waitforcompletion"
	add_dynamic_cmd_param "      -responseFile /home/oracle/oracle_$db.rsp\""
	exec_dynamic_cmd -c "ssh oracle@${node_names[0]}"
	ret=$?
	LN
	[ $ret -gt 250 ] && exit 1
}

function exec_post_install_root_scripts_on_node	# $1 node name
{
	typeset  -r node_name=$1

	typeset -r script_root_sh="/$ORCL_DISK/app/oracle/$oracle_release/dbhome_1/root.sh"
	typeset -r backup_script_root_sh="/home/oracle/root.sh.backup_install"
	line_separator
	exec_cmd "ssh -t -t root@${node_name} \"LANG=C $script_root_sh\" </dev/null"
	LN

	# Je viens de découvrir ça :
	# 8.3.1 Creating a Backup of the root.sh Script
	info "Backup the root.sh script to $backup_script_root_sh"
	exec_cmd "ssh -t -t root@${node_name} 'cp $script_root_sh $backup_script_root_sh'"
	LN
}

function next_instructions
{
	line_separator
	if [ $primary_db_server == none ]
	then
		info "Database can be created :"
		LN
		if [ $max_nodes -eq 1 ]
		then
			info "$ ssh oracle@${node_names[0]}"
			info "oracle@${node_names[0]}:NOSID:oracle> cd db"
			info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db"
			LN
		else
			info "$ ssh oracle@${node_names[0]}"
			info "oracle@${node_names[0]}:NOSID:oracle> cd db"
			LN
			info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db"
			info "or"
			info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db -policyManaged"
			info "or"
			info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db -db_type=RACONENODE"
			LN
		fi
	else
		#	Remarque db contient le nom de la standby et standby contient le
		#	nom de la base existante, les noms sont inversés.
		info "Create standby database $db from $primary_db_server"
		LN

		add_dynamic_cmd_param "-user1=oracle"
		add_dynamic_cmd_param "-server1=srv${db}01"
		add_dynamic_cmd_param "-server2=srv${primary_db_server}01"
		exec_dynamic_cmd "~/plescripts/ssh/setup_ssh_equivalence.sh"
		LN

		info "Execute :"
		info "$ ssh oracle@srv${primary_db_server}01"
		info "$ cd ~/plescripts/db/stby/"
		info "$ ./create_dataguard.sh -standby=$db -standby_host=srv${db}01"
		LN
	fi
}

#	============================================================================
#	MAIN
#	============================================================================
script_start

line_separator
for (( inode=1; inode <= max_nodes; ++inode ))
do
	load_node_cfg $inode
done

info "Total nodes #${max_nodes}"
if [ $max_nodes -gt 1 ]
then
	info "==> clusterNodes  = $clusterNodes"

	if [ $cfg_oracle_home == ocfs2 ]
	then	#	oraInventory ne peut pas être sur un CFS.
		ORA_INVENTORY=/$GRID_DISK/app/oraInventory
	else
		ORA_INVENTORY=/$ORCL_DISK/app/oraInventory
	fi
else
	ORA_INVENTORY=/$ORCL_DISK/app/oraInventory
fi
LN

create_response_file

[ $action == config ] && exit 0	# Pas d'installation.

exec_cmd wait_server ${node_names[0]}

stats_tt start oracle_installation

copy_response_file

mount_install_directory

start_oracle_installation

for node in ${node_names[*]}
do
	exec_post_install_root_scripts_on_node $node
	LN
done

typeset -r type_disks=$(cat $db_cfg_path/disks | tail -1 | cut -d: -f1)
if [ "$type_disks" == FS ]
then
	exec_cmd "ssh -t root@${node_names[0]}	\
		\"~/plescripts/database_servers/create_systemd_service_oracledb.sh\""
fi

stats_tt stop oracle_installation

script_stop $ME $db
LN

next_instructions
