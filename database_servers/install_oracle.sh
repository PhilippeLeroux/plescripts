#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset db=undef
typeset action=install
typeset edition=EE

typeset install_oracle=yes
typeset relink=no
typeset attachHome=no

add_usage "-db=name"			"Database identifier"
add_usage "[-edition=$edition]"	"RAC 12.2 :SE|EE else EE."
typeset -r u1=$(print_usage)
reset_usage

add_usage "[-action=$action]"		"install|config : config no installation"
add_usage "[-skip_install_oracle]"	"Not execute runInstaller"
add_usage "[-relink]"				"Skip runInstaller, relink only"
add_usage "[-attachHome]"			"Skip runInstaller, attach home only"

typeset -r str_usage=\
"Usage : $ME
$u1

Debug flags :
$(print_usage)
"

reset_usage

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

		-edition=*)
			edition=$(to_upper ${1##*=})
			shift
			;;

		-action=*)
			action=${1##*=}
			shift
			;;

		-skip_install_oracle)
			install_oracle=no
			shift
			;;

		-relink)
			relink=yes
			shift
			;;

		-attachHome)
			attachHome=yes
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

ple_enable_log -params $PARAMS

exit_if_param_undef		db							"$str_usage"
exit_if_param_invalid	action	"install config"	"$str_usage"

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

typeset		primary_db=none

if [ "$oracle_release" == "12.2.0.1" ]
then
	exit_if_param_invalid	edition "EE SE2"	"$str_usage"
else
	exit_if_param_invalid	edition "EE"		"$str_usage"
fi

# $1 inode
function load_node_cfg
{
	typeset	-ri	inode=$1

	info "Load node #${inode}"
	cfg_load_node_info $db $inode

	if [[ $inode -eq $max_nodes && $cfg_standby != none ]]
	then
		if [ -d $cfg_path_prefix/$cfg_standby ]
		then # La config exist, donc sur ce serveur créer une standby
			primary_db=$cfg_standby
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

function create_response_file_12cR1
{
	line_separator
	info "Create response file for Oracle software."
	exit_if_file_not_exists template_oracle_${oracle_release%.*.*}.rsp
	exec_cmd cp -f template_oracle_${oracle_release%.*.*}.rsp $rsp_file
	LN

	if [ $cfg_db_type == fs ]
	then
		typeset	-r	O_BASE=/$ORCL_SW_FS_DISK/app/oracle
	else
		typeset	-r	O_BASE=/$ORCL_DISK/app/oracle
	fi

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

function create_response_file_12cR2
{
	line_separator
	info "Create response file for Oracle software."
	exit_if_file_not_exists template_oracle_${oracle_release%.*.*}.rsp
	exec_cmd cp -f template_oracle_${oracle_release%.*.*}.rsp $rsp_file
	LN

	if [ $cfg_db_type == fs ]
	then
		typeset	-r	O_BASE=/$ORCL_SW_FS_DISK/app/oracle
	else
		typeset	-r	O_BASE=/$ORCL_DISK/app/oracle
	fi

	typeset	-r	O_HOME=$O_BASE/$oracle_release/dbhome_1

	update_value oracle.install.option					INSTALL_DB_SWONLY	$rsp_file
	update_value UNIX_GROUP_NAME						oinstall			$rsp_file
	update_value INVENTORY_LOCATION						$ORA_INVENTORY		$rsp_file
	update_value ORACLE_HOME							$O_HOME				$rsp_file
	update_value ORACLE_BASE							$O_BASE				$rsp_file
	update_value oracle.install.db.CLUSTER_NODES		empty				$rsp_file
	update_value oracle.install.db.InstallEdition		$edition			$rsp_file
	update_value oracle.install.db.OSDBA_GROUP			dba					$rsp_file
	update_value oracle.install.db.OSOPER_GROUP			oper				$rsp_file
	update_value oracle.install.db.OSBACKUPDBA_GROUP	dba					$rsp_file
	update_value oracle.install.db.OSDGDBA_GROUP		dba					$rsp_file
	update_value oracle.install.db.OSKMDBA_GROUP		dba					$rsp_file

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

# $1 server
function check_oracle_size
{
	typeset -r server=$1

	exec_cmd "ssh oracle@$server '. .bash_profile && plescripts/database_servers/check_bin_oracle_size.sh'"
}

function start_oracle_installation
{
	if [ $max_nodes -ne 1 ]
	then
		line_separator
		for node in ${node_names[*]}
		do
			# Il faut vraiment attendre.
			exec_cmd -c "ssh -t root@${node}	\
				'~/plescripts/database_servers/test_synchro_ntp.sh -max_loops=100'"
			LN
		done
	fi

	function restore_swappiness
	{
		line_separator
		info "Restore swappiness."
		exec_cmd "ssh root@${node_names[0]} 'sysctl -w vm.swappiness=$vm_swappiness'"
		LN
	}

	line_separator
	# Parfois le link échoue : favorise le swap
	info "Adjust swappiness for link step."
	typeset -r vm_swappiness=$(ssh root@${node_names[0]} 'sysctl -n vm.swappiness')
	exec_cmd "ssh root@${node_names[0]} 'sysctl -w vm.swappiness=90'"
	LN

	line_separator
	case $edition in
		EE)
			info "Install Oracle Enterprise Edition (~10mn)"
			;;
		SE2)
			info "Install Oracle Standard Edition 2 (~10mn)"
			;;
		*)
			warning "Install Oracle $edition"
			;;
	esac
	info "Logs : $ORA_INVENTORY/logs"
	add_dynamic_cmd_param "\"LANG=C /mnt/oracle_install/database/runInstaller"
	add_dynamic_cmd_param "      -silent"
	add_dynamic_cmd_param "      -showProgress"
	add_dynamic_cmd_param "      -waitforcompletion"
	add_dynamic_cmd_param "      -responseFile /home/oracle/oracle_$db.rsp\""
	exec_dynamic_cmd -c "ssh oracle@${node_names[0]}"
	if [ $? -gt 250 ]
	then
		LN
		restore_swappiness
		error "Oracle installation failed."
		LN

		if grep -q "[FATAL] Unable to read the Oracle Home information" $PLELIB_LOG_FILE
		then
			info "Error : [FATAL] Unable to read the Oracle Home information at ..."
			info "add option -attachHome"
			info "$ME -db=$db -attachHome"
			LN
		else
			os_memory_mb=$(ssh root@${node_names[0]} "free -m|grep \"Mem:\"|awk '{ print \$2 }'")
			if [[ $cfg_orarel == 12.2.0.1 && $os_memory_mb -lt $oracle_memory_mb_prereq ]]
			then
				info "On link errors try :"
				info "Rerun script with option -relink"
				info "$ME -db=$db -relink"
				LN
			fi
		fi
		exit 1
	fi
	LN

	restore_swappiness

	check_oracle_size ${node_names[0]}
}

function exec_post_install_root_scripts_on_node	# $1 node name
{
	typeset  -r node_name=$1

	if [ $cfg_db_type == fs ]
	then
		typeset -r script_root_sh="/$ORCL_SW_FS_DISK/app/oracle/$oracle_release/dbhome_1/root.sh"
	else
		typeset -r script_root_sh="/$ORCL_DISK/app/oracle/$oracle_release/dbhome_1/root.sh"
	fi
	typeset -r backup_script_root_sh="/home/oracle/root.sh.backup_install"
	line_separator
	exec_cmd -novar "ssh -t -t root@${node_name} \"LANG=C $script_root_sh\" </dev/null"
	LN

	# Je viens de découvrir ça :
	# 8.3.1 Creating a Backup of the root.sh Script
	info "Backup the root.sh script to $backup_script_root_sh"
	exec_cmd -novar "ssh -t -t root@${node_name} 'cp $script_root_sh $backup_script_root_sh' </dev/null"
	exec_cmd -novar "ssh -t -t root@${node_name} \"chown oracle:oinstall $backup_script_root_sh\" </dev/null"
	LN
}

function exec_relink
{
	line_separator
	for node in ${node_names[*]}
	do
		info "Relink on server $node"
		exec_cmd "ssh -t oracle@${node} '. .bash_profile && plescripts/database_servers/relink_orcl.sh'"
		LN
	done
}

function exec_attachHome
{
	line_separator
	info "Attace home :"
	LN

	info "Read ORACLE_HOME from ${node_names[0]}"
	typeset OH=$(ssh oracle@${node_names[0]} ". .bash_profile && echo \$ORACLE_HOME")
	info "ORACLE_HOME : '$OH'"
	LN

	for (( inode=1; inode < max_nodes; ++inode ))
	do
		info "${node_names[inode]} attach home :"
		exec_cmd "ssh -t oracle@${node_names[inode]} '. .bash_profile && $OH/oui/bin/attachHome.sh'"
		LN
	done
}

function next_instructions
{
	line_separator
	if [ $primary_db == none ]
	then
		notify "Database can be created :"
		LN
		if [ $max_nodes -eq 1 ]
		then
			info "$ ssh oracle@${node_names[0]}"
			info "oracle@${node_names[0]}:NOSID:~> cd db"
			info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db"
			LN
		else
			info "$ ssh oracle@${node_names[0]}"
			info "oracle@${node_names[0]}:NOSID:~> cd db"
			LN
			info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db"
			info "or"
			info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db -policyManaged"
			info "or"
			info "oracle@${node_names[0]}:NOSID:db> ./create_db.sh -db=$db -db_type=RACONENODE"
			LN
		fi
	else
		add_dynamic_cmd_param "-user1=oracle"
		add_dynamic_cmd_param "-server1=srv${db}01"
		add_dynamic_cmd_param "-server2=srv${primary_db}01"
		exec_dynamic_cmd "~/plescripts/ssh/setup_ssh_equivalence.sh"
		LN

		notify "Server srv${primary_db}01 ready"
		LN
		info "Execute :"
		info "$ ssh oracle@srv${primary_db}01"
		info "$ cd ~/plescripts/db/stby/"
		info "$ ./create_dataguard.sh -standby=$db -standby_host=srv${db}01"
		LN
	fi
}

#	============================================================================
#	MAIN
#	============================================================================
script_start

if [[ $relink == yes || $attachHome == yes ]]
then
	info "Flag -relink or/and -attachHome : add flag -skip_install"
	install_oracle=no
	LN
fi

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
	if [ $cfg_db_type == fs ]
	then
		ORA_INVENTORY=/$ORCL_SW_FS_DISK/app/oraInventory
	else
		ORA_INVENTORY=/$ORCL_DISK/app/oraInventory
	fi
fi
LN

if [ $install_oracle == yes ]
then
	case $oracle_release in
		12.1.0.2)
			create_response_file_12cR1
			;;

		12.2.0.1)
			create_response_file_12cR2
			;;

		*)
			error "Oracle $oracle_release not supported."
			exit 1
	esac

	[ $action == config ] && exit 0	# Pas d'installation.

	exec_cmd wait_server ${node_names[0]}

	stats_tt start oracle_installation

	copy_response_file

	mount_install_directory

	start_oracle_installation
fi

[ $relink == yes ] && exec_relink || true

[ $attachHome == yes ] && exec_attachHome || true

for node in ${node_names[*]}
do
	exec_post_install_root_scripts_on_node $node
	LN
done

if [ $cfg_db_type == fs ]
then
	exec_cmd "ssh -t root@${node_names[0]}	\
		\"~/plescripts/database_servers/create_systemd_service_oracledb.sh\""
	LN
fi

exec_cmd "~/plescripts/database_servers/install_sample_schema.sh -db=$db"
LN

stats_tt stop oracle_installation

if [ $install_oracle == yes ]
then
	script_stop $ME $db
	LN
fi

next_instructions
