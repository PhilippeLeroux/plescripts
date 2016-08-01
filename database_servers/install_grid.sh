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
		-db=<str>              Identifiant de la base
		-action=install|config
		   install fait la config et l'installation.
		   config ne fait que la config.

		Pour passer certaine phases de l'installation :
		   -skip_grid_installation
		   -skip_root_scripts
		   -skip_configToolAllCommands
		   -skip_create_dg
		   -install_mgmtdb	(uniquement pour le RAC)

	-oracle_home_for_test permet de tester le script sans que les VMs existent.
"
info "$ME $@"

typeset	db=undef
typeset	action=install

typeset	skip_grid_installation=no
typeset	skip_root_scripts=no
typeset	skip_configToolAllCommands=no
typeset	skip_create_dg=no
typeset	install_mgmtdb=no

typeset oracle_home_for_test=no

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

		-pause=*)
			PAUSE=${1##*=}
			shift
			;;

		-skip_grid_installation)
			skip_grid_installation=yes
			shift
			;;

		-skip_root_scripts)
			skip_root_scripts=yes
			shift
			;;

		-skip_configToolAllCommands)
			skip_configToolAllCommands=yes
			shift
			;;

		-skip_create_dg)
			skip_create_dg=yes
			shift
			;;

		-oracle_home_for_test)
			oracle_home_for_test=yes
			shift
			;;

		-install_mgmtdb)
			install_mgmtdb=yes
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

#	Répertoire contenant le fichiers de configuration de la db
typeset -r cfg_path=~/plescripts/database_servers/$db
[ ! -d $cfg_path ]	&& error "$cfg_path not exists." && exit 1

#	Nom du "fichier réponse" pour l'installation du grid
typeset -r rsp_file=${cfg_path}/grid_$db.rsp

#	Nom du  "fichier propriété" utilisé pour ConfigTool
typeset -r prop_file=${cfg_path}/grid_$db.properties

#
typeset -a node_names
typeset -a node_ips
typeset -a node_vip_names
typeset -a node_vips
typeset -a node_priv_names
typeset -a node_priv_ips
typeset -i max_nodes=0

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
}

function create_response_file	# $1 fichier décrivant les disques
{
	line_separator
	info "Create $rsp_file for grid installation."
	exec_cmd cp -f template_grid.rsp $rsp_file
	LN

	update_value ORACLE_HOSTNAME							${node_names[0]}	$rsp_file
	LN

	update_value ORACLE_BASE								$ORACLE_BASE		$rsp_file
	LN

	update_value ORACLE_HOME								$ORACLE_HOME		$rsp_file
	LN

	update_value oracle.install.asm.SYSASMPassword			$oracle_password	$rsp_file
	LN

	update_value oracle.install.asm.monitorPassword			$oracle_password	$rsp_file
	LN

	typeset -r upper_db=$(to_upper $db)

	if [ $max_nodes -eq 1 ]
	then
		update_value oracle.install.option							HA_CONFIG		$rsp_file
		LN
		update_value oracle.install.asm.diskGroup.name				DATA			$rsp_file
		LN
		update_value oracle.install.asm.diskGroup.redundancy		EXTERNAL		$rsp_file
		LN
		update_value oracle.install.crs.config.gpnp.scanName		empty			$rsp_file
		LN
		update_value oracle.install.crs.config.gpnp.scanPort		empty			$rsp_file
		LN
		update_value oracle.install.crs.config.clusterName			empty			$rsp_file
		LN
		update_value oracle.install.crs.config.clusterNodes			empty			$rsp_file
		LN
		update_value oracle.install.crs.config.networkInterfaceList empty			$rsp_file
		LN
		update_value oracle.install.crs.config.storageOption		empty			$rsp_file
		LN
		typeset -ri last_disks=$(head -1 $1 | cut -d':' -f 4)
		typeset -i idisk=1
		while [ $idisk -le $last_disks ]
		do
			if [ $idisk -eq 1 ]
			then
				disks=$(printf "ORCL:S1DISK${upper_db}%02d" $idisk)
			else
				disks=$(printf "$disks,ORCL:S1DISK${upper_db}%02d" $idisk)
			fi
			idisk=idisk+1
		done
		update_value oracle.install.asm.diskGroup.disks $disks $rsp_file
		LN

	else
		update_value oracle.install.option						CRS_CONFIG				$rsp_file
		LN
		update_value oracle.install.asm.diskGroup.name			CRS						$rsp_file
		LN
		update_value oracle.install.crs.config.gpnp.scanName	$scan_name				$rsp_file
		LN
		update_value oracle.install.crs.config.gpnp.scanPort	1521					$rsp_file
		LN
		update_value oracle.install.crs.config.clusterName		$scan_name				$rsp_file
		LN
		update_value oracle.install.crs.config.clusterNodes		$clusterNodes			$rsp_file
		LN
		nil=$if_pub_name:${if_pub_network}.0:1,$if_priv_name:${if_priv_network}.0:2
		update_value oracle.install.crs.config.networkInterfaceList $nil				$rsp_file
		LN
		update_value oracle.install.crs.config.storageOption	LOCAL_ASM_STORAGE		$rsp_file
		LN

		#	Pour le CRS on prend les 3 premiers disques.
		disks="ORCL:S1DISK${upper_db}01,ORCL:S1DISK${upper_db}02,ORCL:S1DISK${upper_db}03"
		update_value oracle.install.asm.diskGroup.disks $disks $rsp_file
	fi
}

function create_property_file
{
	info "Create property file ConfigTool : $prop_file"
	(	echo "oracle.assistants.asm|S_ASMPASSWORD=$oracle_password"
		echo "oracle.assistants.asm|S_ASMMONITORPASSWORD=$oracle_password"
	)	>  $prop_file
}

function copy_response_and_properties_files
{
	line_separator
	info "Response file   : $rsp_file"
	info "Properties file : $prop_file"
	info "Copy files to ${node_names[0]}:/home/grid/"
	exec_cmd "scp $rsp_file $prop_file grid@${node_names[0]}:/home/grid/"
}

function mount_install_directory
{
	line_separator
	info "Mount install directory :"
	exec_cmd -cont "ssh root@${node_names[0]} mount /mnt/oracle_install"
}

function start_grid_installation
{
	line_separator
	info "Start grid installation (~17mn)."
	exec_cmd -c "ssh -t grid@${node_names[0]} \"LANG=C /mnt/oracle_install/grid/runInstaller -silent -showProgress -waitforcompletion -responseFile /home/grid/grid_$db.rsp\""
	ret=$?
	[ $ret -gt 250 ] && exit 1
}

function run_post_install_root_scripts_on_node	# $1 No node
{
	typeset  -ri inode=$1
	[ $# -eq 0 ] && error "$0 <node number>" && exit 1

	line_separator
	info "Run post install scripts on node ${node_names[$inode]} (~10mn)"
	exec_cmd "ssh -t root@${node_names[$inode]} \"LANG=C /u01/app/oraInventory/orainstRoot.sh\""
	LN
	exec_cmd "ssh -t -t root@${node_names[$inode]} \"LANG=C $ORACLE_HOME/root.sh\""
}

function runConfigToolAllCommands
{
	line_separator
	info "Run ConfigTool"
	exec_cmd "ssh -t grid@${node_names[0]} \"LANG=C $ORACLE_HOME/cfgtoollogs/configToolAllCommands RESPONSE_FILE=/home/grid/grid_${db}.properties\""
}

function create_dg # $1 nom du DG
{
	typeset -r DG=$1

	info "Create DG : $DG"
	IFS=':' read dg_name size first last<<<"$(cat $cfg_path/disks | grep "^${DG}")"
	total_disks=$(( $last - $first + 1 ))
	exec_cmd "ssh -t grid@${node_names[0]} \". ./.profile; ~/plescripts/dg/create_new_dg.sh -name=$DG -disks=$total_disks -nomount\""
}

#	Création des DGs.
#	- Pour un serveur standalone création du DG FRA.
#	- Pour un serveur RAC création des DG DATA & FRA puis montage sur les autres nœuds.
function create_all_dgs
{
	line_separator

	# Pour le RAC uniquement, le premier DG étant CRS ou GRID
	[ $max_nodes -gt 1 ] && create_dg DATA

	create_dg FRA

	if [ $max_nodes -ne 1 ]
	then	# Sur les autres noeaud les DGs sont à monter uniquement.
		typeset -i inode=1
		while [ $inode -lt $max_nodes ]
		do
			if [ $max_nodes -gt 1 ]
			then
				info "mount DG DATA on ${node_names[$inode]}"
				exec_cmd "ssh -t grid@${node_names[$inode]} \". ./.profile; asmcmd mount DATA\""
				LN
			fi

			info "mount DG FRA on ${node_names[$inode]}"
			exec_cmd "ssh -t grid@${node_names[$inode]} \". ./.profile; asmcmd mount FRA\""
			LN

			inode=inode+1
		done
	fi
}

function launch_memstat
{
	typeset mode="-h"
	[ "$DEBUG_PLE" = yes ] && mode=""

	for i in $( seq 0 $(( max_nodes - 1 )) )
	do
		exec_cmd $mode -c "ssh -n grid@${node_names[$i]} \
		\"nohup ~/plescripts/memory/memstats.sh -title=install_grid >/dev/null 2>&1 &\""
	done
}

function on_exit
{
	[ "$INSTALL_GRAPH" != YES ] && return 0

	typeset mode="-h"
	[ "$DEBUG_PLE" = yes ] && mode=""

	for i in $( seq 0 $(( max_nodes - 1 )) )
	do
		exec_cmd $mode -c "ssh -t grid@${node_names[$i]} \
		\"~/plescripts/memory/memstats.sh -kill -title=install_grid >/dev/null 2>&1\""
	done
}

function disclaimer
{
	info "****************************************************"
	info "* Not supported by Oracle Corporation              *"
	info "* For personal use only, on a desktop environment. *"
	info "****************************************************"
}

function stop_and_disable_unwanted_grid_ressources
{
	line_separator
	disclaimer
	exec_cmd "ssh -t root@${node_names[0]} . /root/.bash_profile \; crsctl stop res ora.crf -init"
	exec_cmd "ssh -t root@${node_names[0]} . /root/.bash_profile \; crsctl delete res ora.crf -init"
	exec_cmd "ssh -t root@${node_names[0]} . /root/.bash_profile \; srvctl stop cvu"
	exec_cmd "ssh -t root@${node_names[0]} . /root/.bash_profile \; srvctl disable cvu"
	exec_cmd "ssh -t root@${node_names[0]} . /root/.bash_profile \; srvctl stop oc4j"
	exec_cmd "ssh -t root@${node_names[0]} . /root/.bash_profile \; srvctl disable oc4j"
}

function set_ASM_memory_target_low_and_restart_cluster
{
	line_separator
	disclaimer
	exec_cmd "ssh grid@${node_names[0]} \". ~/.profile; ~/plescripts/database_servers/set_ASM_memory_target_low.sh\""
	exec_cmd "ssh -t root@${node_names[0]} \". ~/.bash_profile; srvctl stop asm -f\""
	exec_cmd "ssh -t root@${node_names[0]} \". ~/.bash_profile; srvctl start asm\""
	LN
}

function remove_tfa_on_all_nodes
{
	line_separator
	disclaimer
	for i in $( seq 0 $(( max_nodes - 1 )) )
	do
		exec_cmd $mode -c "ssh -n root@${node_names[$i]} . /root/.bash_profile \; tfactl uninstall"
	done
}

trap on_exit EXIT

#	======================================================================
#	MAIN
#	======================================================================
typeset -r script_start_at=$SECONDS

line_separator
for file in $cfg_path/node*
do
	load_node_cfg $file $max_nodes
	max_nodes=max_nodes+1
done

info "Total nodes #${max_nodes}"
if [ $max_nodes -gt 1 ]
then
	exit_if_file_not_exists $cfg_path/scanvips
	typeset -r scan_name=$(cat $cfg_path/scanvips | cut -d':' -f1)

	info "==> scan name     = $scan_name"
	info "==> clusterNodes  = $clusterNodes"
fi
LN

if [ $oracle_home_for_test = no ]
then
	#	On doit récupérer l'ORACLE_HOME du grid qui est différent entre 1 cluster et 1 single.
	ORACLE_HOME=$(ssh grid@${node_names[0]} ". ~/.profile; env|grep ORACLE_HOME"|cut -d= -f2)
	ORACLE_BASE=$(ssh grid@${node_names[0]} ". ~/.profile; env|grep ORACLE_BASE"|cut -d= -f2)
else
	ORACLE_HOME=/u01/oracle_home/bidon
	ORACLE_BASE=/u01/oracle_base/bidon
fi

info "ORACLE_HOME = '$ORACLE_HOME'"
info "ORACLE_BASE = '$ORACLE_BASE'"

[ x"$ORACLE_HOME" == x ] && error "Can't read ORACLE_HOME for user grid on ${node_names[0]}" && exit 1

if [ $skip_grid_installation == no ]
then
	if [ $action == config ] || [ $action == install ]
	then
		create_response_file $cfg_path/disks
		LN

		create_property_file
		LN
	fi
fi

if [ $action == install ]
then
	if [ $oracle_home_for_test != no ]
	then
		error "Never use -action=install & -oracle_home_for_test"
		exit 1
	fi

	~/plescripts/shell/wait_server ${node_names[0]}

	[ "$INSTALL_GRAPH" == YES ] && launch_memstat

	if [ $skip_grid_installation != yes ]
	then
		copy_response_and_properties_files
		LN

		mount_install_directory
		LN

		start_grid_installation
		LN
	fi

	if [ $skip_root_scripts != yes ]
	then #	Il faut toujours commencer sur le noeud d'installation du grid.
		typeset -i inode=0
		while [ $inode -lt $max_nodes ]
		do
			run_post_install_root_scripts_on_node $inode
			LN
			inode=inode+1
		done
	fi

	if [ $skip_configToolAllCommands == no ]
	then
		if [ $max_nodes -gt 1 ]
		then	#	RAC
			if [ $install_mgmtdb == no ]
			then
				remove_tfa_on_all_nodes
				LN

				stop_and_disable_unwanted_grid_ressources
				LN

				set_ASM_memory_target_low_and_restart_cluster
				LN
			else
				runConfigToolAllCommands
			fi
		else	#	SINGLE
			line_separator
			runConfigToolAllCommands
			LN

			line_separator
			disclaimer
			exec_cmd "ssh grid@${node_names[0]} \". ~/.profile; ~/plescripts/database_servers/set_ASM_memory_target_low.sh\""
			exec_cmd -c "ssh -t root@${node_names[0]} \". ~/.bash_profile; srvctl stop asm -f\""
			exec_cmd -c "ssh -t root@${node_names[0]} \". ~/.bash_profile; srvctl start asm\""
			LN

			#Pour être certain que ASM est démarré.
			[ $max_nodes -eq 1 ] && (info -n "Wait : "; pause_in_secs 30; LN)
		fi
	fi

	[ $skip_create_dg != yes ] && create_all_dgs || true
fi

if [ $oracle_home_for_test == no ]
then
	info "Installation status :"
	exec_cmd "ssh grid@${node_names[0]} \". ~/.profile; crsctl stat res -t\""
	LN
fi

info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
LN

info "The Oracle software can be installed."
info "./install_oracle.sh -db=$db"
LN
