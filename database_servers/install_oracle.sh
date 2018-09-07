#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset		db=undef
typeset	-i	dg_node=-1
typeset		action=install
typeset		edition=EE

typeset		install_oracle=yes
typeset		relink=no
typeset		attachHome=no

add_usage "-db=name"			"Database identifier"
add_usage "[-dg_node=#]"		"Dataguard node number 1 or 2"
add_usage "[-edition=$edition]"	"12.2 only : SE2|EE"
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

		-dg_node=*)
			dg_node=${1##*=}
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

#	Répertoire contenant le fichier de configuration de la db
typeset	-r	db_cfg_path=$cfg_path_prefix/$db

#	Nom du "fichier réponse" pour l'installation d'oracle
typeset	-r	rsp_file=${db_cfg_path}/oracle_$db.rsp

#
typeset	-a	node_names
typeset	-a	node_ips
typeset	-a	node_vip_names
typeset	-a	node_vips
typeset	-a	node_priv_names
typeset	-a	node_priv_ips
typeset	-ri	max_nodes=$(cfg_max_nodes $db)

function empty_swap
{
	line_separator
	info "Empty swap on nodes ${node_names[*]}"
	for node in ${node_names[*]}
	do
		exec_cmd "ssh root@${node} 'swapoff -a && swapon -a'"
		LN
	done
}

# $1 inode
function load_node_cfg
{
	typeset	-ri	inode=$1

	info "Load node #${inode}"
	cfg_load_node_info $db $inode

	if [[ $cfg_dataguard == yes && $dg_node -eq -1 ]]
	then
		error "Dataguard, parameter -dg_node=# missing"
		LN
		info "$str_usage"
		LN
		exit 1
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
	exit_if_file_not_exists template_oracle_${cfg_orarel%.*.*}.rsp
	exec_cmd cp -f template_oracle_${cfg_orarel%.*.*}.rsp $rsp_file
	LN

	if [ $cfg_db_type == fs ]
	then
		typeset	-r	O_BASE=/$orcl_sw_fs_disk/app/oracle
	else
		typeset	-r	O_BASE=/$orcl_disk/app/oracle
	fi

	typeset	-r	O_HOME=$O_BASE/$cfg_orarel/dbhome_1

	update_variable oracle.install.option				INSTALL_DB_SWONLY	$rsp_file
	update_variable ORACLE_HOSTNAME						${node_names[0]}	$rsp_file
	update_variable UNIX_GROUP_NAME						oinstall			$rsp_file
	update_variable INVENTORY_LOCATION					$ORA_INVENTORY		$rsp_file
	update_variable ORACLE_HOME							$O_HOME				$rsp_file
	update_variable ORACLE_BASE							$O_BASE				$rsp_file
	update_variable oracle.install.db.CLUSTER_NODES		empty				$rsp_file
	update_variable oracle.install.db.InstallEdition	EE					$rsp_file
	update_variable oracle.install.db.DBA_GROUP			dba					$rsp_file
	update_variable oracle.install.db.OPER_GROUP		oper				$rsp_file
	update_variable oracle.install.db.BACKUPDBA_GROUP	dba					$rsp_file
	update_variable oracle.install.db.DGDBA_GROUP		dba					$rsp_file
	update_variable oracle.install.db.KMDBA_GROUP		dba					$rsp_file

	if [[ $cfg_db_type == rac ]]
	then
		server_list=${node_names[0]}
		for (( inode=1; inode < max_nodes; ++inode ))
		do
			server_list=$server_list","${node_names[inode]}
		done

		update_variable oracle.install.db.CLUSTER_NODES "$server_list" $rsp_file
	fi
	LN
}

function create_response_file_12cR2
{
	line_separator
	info "Create response file for Oracle software."
	exit_if_file_not_exists template_oracle_${cfg_orarel%.*.*}.rsp
	exec_cmd cp -f template_oracle_${cfg_orarel%.*.*}.rsp $rsp_file
	LN

	if [ $cfg_db_type == fs ]
	then
		typeset	-r	O_BASE=/$orcl_sw_fs_disk/app/oracle
	else
		typeset	-r	O_BASE=/$orcl_disk/app/oracle
	fi

	typeset	-r	O_HOME=$O_BASE/$cfg_orarel/dbhome_1

	update_variable oracle.install.option				INSTALL_DB_SWONLY	$rsp_file
	update_variable UNIX_GROUP_NAME						oinstall			$rsp_file
	update_variable INVENTORY_LOCATION					$ORA_INVENTORY		$rsp_file
	update_variable ORACLE_HOME							$O_HOME				$rsp_file
	update_variable ORACLE_BASE							$O_BASE				$rsp_file
	update_variable oracle.install.db.CLUSTER_NODES		empty				$rsp_file
	update_variable oracle.install.db.InstallEdition	$edition			$rsp_file
	update_variable oracle.install.db.OSDBA_GROUP		dba					$rsp_file
	update_variable oracle.install.db.OSOPER_GROUP		oper				$rsp_file
	update_variable oracle.install.db.OSBACKUPDBA_GROUP	dba					$rsp_file
	update_variable oracle.install.db.OSDGDBA_GROUP		dba					$rsp_file
	update_variable oracle.install.db.OSKMDBA_GROUP		dba					$rsp_file

	if [[ $cfg_db_type == rac ]]
	then
		server_list=${node_names[0]}
		for (( inode=1; inode < max_nodes; ++inode ))
		do
			server_list=$server_list","${node_names[inode]}
		done

		update_variable oracle.install.db.CLUSTER_NODES "$server_list" $rsp_file
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

# $1 server
function check_oracle_size
{
	if grep -qE "Error in invoking target 'irman ioracle'" $PLELIB_LOG_FILE
	then # Test non testé.
		warning "Link error apply workaround."
		exec_relink
	fi

	typeset -r server=$1
	exec_cmd "ssh oracle@$server '. .bash_profile && plescripts/database_servers/check_bin_oracle_size.sh'"
	LN
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

function check_ntp_error
{
	typeset -r log_line=$(grep -E "ACTION: Identify the list of failed prerequisite checks from the log:" $PLELIB_LOG_FILE)

	[ x"$log_line" == x ] && return 0 || true

	#'   ACTION: Identify the list of failed prerequisite checks from the log: /u01/app/oraInventory/logs/installActions2017-09-22_11-40-49AM.log. Then either from the log file or from installation manual find the appropriate configuration to meet the prerequisites and fix it manually.'
	typeset -r orcl_log=$(sed "s/.*log: \(\/.*log\)\. .*/\1/"<<<"$log_line")

	if ssh oracle@${node_names[0]} "grep -qE \"PRVG-13602\" $orcl_log"
	then
		error "NTP error : reboot VMs ${node_names[*]} and rerun script."
		LN
	fi
}

function start_oracle_installation
{
	if [[ $cfg_db_type == rac ]]
	then
		line_separator
		for node in ${node_names[*]}
		do
			exec_cmd "ssh -t root@${node} '~/plescripts/ntp/test_synchro_ntp.sh'"
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
	ret=$?
	LN
	if [ $ret -gt 250 ]
	then
		if grep -qE "^\[FATAL\] Unable to read the Oracle Home information at" $PLELIB_LOG_FILE
		then # L'erreur ne ce produit qu'avec le RAC 12.2
			warning "Error : [FATAL] Unable to read the Oracle Home information at ..."
			warning "Apply workaround"
			LN
			exec_attachHome

			info "Workaround applied."
			LN
		else
			restore_swappiness
			error "Oracle installation failed."
			LN

			if ! check_ntp_error
			then
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
	fi

	restore_swappiness

	check_oracle_size ${node_names[0]}
}

# $1 node name
function exec_post_install_root_scripts_on_node
{
	typeset  -r node_name=$1

	if [ $cfg_db_type == fs ]
	then
		typeset -r script_root_sh="/$orcl_sw_fs_disk/app/oracle/$cfg_orarel/dbhome_1/root.sh"
	else
		typeset -r script_root_sh="/$orcl_disk/app/oracle/$cfg_orarel/dbhome_1/root.sh"
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

function next_instructions
{
	line_separator
	if [[ $cfg_dataguard == no ]]
	then
		notify "Database can be created :"
		LN
		if [ $cfg_db_type != rac ]
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
		if [ $dg_node -eq 1 ]
		then
			notify "Server srv${db}01 ready, install Oracle on second member."
			LN
			info "Execute : $ME -db=$db -dg_node=2"
			LN
		else # dg_node == 2
			notify "Server srv${db}02 ready"
			LN

			info "Database can be created :"
			LN
			info "$ ssh oracle@srv${db}01"
			info "oracle@srv${db}01:NOSID:~> cd db"
			info "oracle@srv${db}01:NOSID:db> ./create_db.sh -db=${db}01"
			LN
		fi
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
# Chargement de la configuration.
if [ $dg_node -eq -1 ]
then
	for (( inode=1; inode <= max_nodes; ++inode ))
	do
		load_node_cfg $inode
	done
else
	load_node_cfg $dg_node
fi

if [ "$cfg_orarel" != "${oracle_release}" ]
then
	warning "Bad Oracle Release"
	exec_cmd ~/plescripts/update_local_cfg.sh ORACLE_RELEASE=$cfg_orarel

	info "Rerun with local config updated."
	exec_cmd $ME $PARAMS
	LN
	exit 0
fi

if [ "$cfg_orarel" == "12.2.0.1" ]
then
	exit_if_param_invalid	edition "EE SE2"	"$str_usage"
else
	exit_if_param_invalid	edition "EE"		"$str_usage"
fi

info "Total nodes #${max_nodes}"
case $cfg_db_type in
	rac)
		info "==> clusterNodes  = $clusterNodes"
		if [ $cfg_oracle_home == ocfs2 ]
		then	#	oraInventory ne peut pas être sur un CFS.
			ORA_INVENTORY=/$grid_disk/app/oraInventory
		else
			ORA_INVENTORY=/$orcl_disk/app/oraInventory
		fi
		;;
	fs)	# Base sur FS
		info "Database on FS"
		ORA_INVENTORY=/$orcl_sw_fs_disk/app/oraInventory
		;;
	std)  # Base sur ASM
		info "Database on ASM"
		ORA_INVENTORY=/$orcl_disk/app/oraInventory
		;;
esac
LN

if [ $install_oracle == yes ]
then
	case $cfg_orarel in
		12.1.0.2)
			create_response_file_12cR1
			;;

		12.2.0.1)
			create_response_file_12cR2
			;;

		*)
			error "Oracle $cfg_orarel not supported."
			exit 1
	esac

	[ $action == config ] && exit 0	# Pas d'installation.

	exec_cmd wait_server ${node_names[0]}
	LN

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

empty_swap

if [ $dg_node -eq 1 ]
then
	line_separator
	add_dynamic_cmd_param "-user1=oracle"
	add_dynamic_cmd_param "-server1=srv${db}01"
	add_dynamic_cmd_param "-server2=srv${db}02"
	exec_dynamic_cmd "~/plescripts/ssh/setup_ssh_equivalence.sh"
	LN
fi

if [[ $cfg_db_type == rac && $cfg_oracle_home == ocfs2 ]]
then
	line_separator
	info "Check Oracle software file system."
	exec_cmd "ssh -t root@${node_names[0]}	\
				'. .bash_profile && disk/ocfs2_fsck.sh -db=$db -db_is_stopped'"
fi

script_stop $ME $db
LN

next_instructions
