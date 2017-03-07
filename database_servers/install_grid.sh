#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name       Identifiant de la base
	-rsp_file_only Uniquement créer le fichier réponse, pas d'installation.

	Pour passer certaine phases de l'installation :
	   -skip_grid_install
	   -skip_root_scripts
	   -skip_configToolAllCommands
	   -skip_create_dg

	Par défaut des hacks sont fait pour diminuer la consommation mémoire :
		* Réduction de la mémoire ASM
		* Arrêt de certains services.
		* Suppression de tfa
		* La base MGMTDB n'est pas crées.
	Le flag -no_hacks permet de ne pas mettre en œuvre ces hacks.
	Le flag -force_MGMTDB force l'installation de la base en conservant les autres hacks.

	-oracle_home_for_test permet de tester le script sans que les VMs existent.
"

typeset	db=undef
typeset	rsp_file_only=no

typeset	skip_grid_install=no
typeset	skip_root_scripts=no
typeset	skip_configToolAllCommands=no
typeset	skip_create_dg=no
typeset	do_hacks=yes
typeset force_MGMTDB=no

typeset oracle_home_for_test=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-rsp_file_only)
			rsp_file_only=yes
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-pause=*)
			PAUSE=${1##*=}
			shift
			;;

		-skip_grid_install)
			skip_grid_install=yes
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

		-no_hacks)
			do_hacks=no
			shift
			;;

		-force_MGMTDB)
			force_MGMTDB=yes
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

ple_enable_log

script_banner $ME $*

exit_if_param_undef	db	"$str_usage"

cfg_exists $db

typeset -r db_cfg_path=$cfg_path_prefix/$db

#	Nom du "fichier réponse" pour l'installation du grid
typeset -r rsp_file=${db_cfg_path}/grid_$db.rsp

#	Nom du  "fichier propriété" utilisé pour ConfigTool
typeset -r prop_file=${db_cfg_path}/grid_$db.properties

#
typeset -a	node_names
typeset -a	node_ips
typeset -a	node_vip_names
typeset -a	node_vips
typeset -a	node_iscsi_names
typeset -a	node_iscsi_ips
typeset -ri	max_nodes=$(cfg_max_nodes $db)

#	$1 account name
#	Execute on node 0 (node_names[0]) command "$@" (execpt first arg
function ssh_node0
{
	typeset -r account=$1
	shift
	exec_cmd "ssh -t ${account}@${node_names[0]} \". .bash_profile; $@\""
}

function load_node_cfg # $1 inode
{
	typeset	-ri	inode=$1

	info "Load node #${inode}"
	cfg_load_node_info $db $inode

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

#	Fabrique oracle.install.asm.diskGroup.disks
#	$1	fichier de description des disques.
function make_disk_list
{
	typeset -r disk_cfg_file="$1"

	#	Les disques sont numérotés à partir de 1, donc le n° du dernier disque
	#	correspond au nombre de disques.
	typeset	-ri	total_disks=$(head -1 $disk_cfg_file | cut -d: -f4)

	#	Lecture des $total_disks premiers disques.
	typeset disk_list
	while read oracle_disk
	do
		[ x"$disk_list" != x ] && disk_list=$disk_list","
		disk_list=$disk_list"ORCL:$oracle_disk"
	done<<<"$(ssh root@${node_names[0]} ". .bash_profile; oracleasm listdisks"|\
															head -$total_disks)"

	echo $disk_list
}

function create_response_file	# $1 fichier décrivant les disques
{
	typeset -r disk_cfg_file="$1"

	line_separator
	info "Create $rsp_file for grid installation."
	exit_if_file_not_exists template_grid_${oracle_release%.*.*}.rsp
	exec_cmd cp -f template_grid_${oracle_release%.*.*}.rsp $rsp_file
	LN

	update_value ORACLE_HOSTNAME							${node_names[0]}	$rsp_file
	update_value ORACLE_BASE								$ORACLE_BASE		$rsp_file
	update_value ORACLE_HOME								$ORACLE_HOME		$rsp_file
	update_value INVENTORY_LOCATION							${ORACLE_BASE%/*/*}/app/oraInventory	$rsp_file
	update_value oracle.install.asm.SYSASMPassword			$oracle_password	$rsp_file
	update_value oracle.install.asm.monitorPassword			$oracle_password	$rsp_file

	if [ $max_nodes -eq 1 ]
	then
		update_value oracle.install.option							HA_CONFIG		$rsp_file
		update_value oracle.install.asm.diskGroup.name				DATA			$rsp_file
		update_value oracle.install.asm.diskGroup.redundancy		EXTERNAL		$rsp_file
		update_value oracle.install.crs.config.gpnp.scanName		empty			$rsp_file
		update_value oracle.install.crs.config.gpnp.scanPort		empty			$rsp_file
		update_value oracle.install.crs.config.clusterName			empty			$rsp_file
		update_value oracle.install.crs.config.clusterNodes			empty			$rsp_file
		update_value oracle.install.crs.config.networkInterfaceList empty			$rsp_file
		update_value oracle.install.crs.config.storageOption		empty			$rsp_file
		update_value oracle.install.asm.diskGroup.disks $(make_disk_list $disk_cfg_file) $rsp_file
	else
		update_value oracle.install.option						CRS_CONFIG				$rsp_file
		update_value oracle.install.asm.diskGroup.name			CRS						$rsp_file
		update_value oracle.install.crs.config.gpnp.scanName	$scan_name				$rsp_file
		update_value oracle.install.crs.config.gpnp.scanPort	1521					$rsp_file
		update_value oracle.install.crs.config.clusterName		$scan_name				$rsp_file
		update_value oracle.install.crs.config.clusterNodes		$clusterNodes			$rsp_file

		typeset	pub_network=$(right_pad_ip $if_pub_network)
		typeset	rac_network=$(right_pad_ip $if_rac_network)
		typeset nil=$if_pub_name:${pub_network}:1,$if_rac_name:${rac_network}:2
		update_value oracle.install.crs.config.networkInterfaceList $nil				$rsp_file
		update_value oracle.install.crs.config.storageOption	LOCAL_ASM_STORAGE		$rsp_file
		update_value oracle.install.asm.diskGroup.disks $(make_disk_list $disk_cfg_file) $rsp_file
	fi
	LN
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
	exec_cmd -c "ssh root@${node_names[0]} mount /mnt/oracle_install"
}

function start_grid_installation
{
	line_separator
	info "Start grid installation (~12mn)."
	add_dynamic_cmd_param "\"LANG=C /mnt/oracle_install/grid/runInstaller"
	add_dynamic_cmd_param "      -silent"
	add_dynamic_cmd_param "      -showProgress"
	add_dynamic_cmd_param "      -waitforcompletion"
	add_dynamic_cmd_param "      -responseFile /home/grid/grid_$db.rsp\""
	exec_dynamic_cmd -c "ssh -t grid@${node_names[0]}"
	if [[ $? -gt 250 || $? -eq 127 ]]
	then
		error "To check errors :"
		error "cd /mnt/oracle_install/grid"
		error "Run : ./runcluvfy.sh stage -pre crsinst -fixup -n $(echo ${node_names[*]} | tr [:space:] ',')"
		exit 1
	fi
	LN
}

function run_post_install_root_scripts_on_node	# $1 node# $2 server_name
{
	typeset	-ri	nr_node=$1
	typeset	-r	server_name=$2

	line_separator
	info "Run post install scripts on node #${nr_node} $server_name (~10mn)"
	LN

	exec_cmd -novar "ssh -t root@$server_name	\
				\"${ORACLE_BASE%/*/*}/app/oraInventory/orainstRoot.sh\""
	LN

	exec_cmd -c -novar "ssh -t -t root@$server_name \". .bash_profile;	\
											$ORACLE_HOME/root.sh\""
	return $?
}

# $1 node name
function print_manual_workaround
{
	typeset node_name=$1
	info "Manual workaround"
	info "> ssh root@${node_name}"
	info "> $ORACLE_HOME/root.sh"
	info "log $OK : ./install_grid.sh -db=$db -skip_grid_install -skip_root_scripts"
	info "log $KO : reboot servers, wait crs up and"
	info "$ ./install_grid.sh -db=$db -skip_grid_install"
	LN
}

function run_post_install_root_scripts
{
	typeset -i inode
	for (( inode=0; inode < max_nodes; ++inode ))
	do
		typeset node_name=${node_names[inode]}

		run_post_install_root_scripts_on_node $((inode+1)) $node_name
		typeset -i ret=$?
		LN

		if [ $ret -ne 0 ]
		then
			error "root scripts on server $node_name failed."
			[ $inode -eq 0 ] && exit 1

			LN
			warning "Workaround :"
			LN

			run_post_install_root_scripts_on_node 0 ${node_names[0]}
			LN

			timing 10
			LN

			run_post_install_root_scripts_on_node $((inode+1)) $node_name
			typeset -i ret=$?
			LN

			if [ $ret -ne 0 ]
			then
				error "Workaround failed."
				LN
				print_manual_workaround $node_name
				exit 1
			fi
		fi

		if [[ $max_nodes -gt 1 && $inode -eq 0 ]]
		then
			timing 10
			LN
		fi
	done
}

# Création de la base : -MGMTDB pour un RAC, je ne sais pas ce qu'il fait d'autre.
# Est ce qu'il ne serait pas mieux d'exécuter le script puis détruire la base ?
function runConfigToolAllCommands
{
	line_separator
	info "Run ConfigTool"
	exec_cmd "ssh -t grid@${node_names[0]}								\
				\"LANG=C $ORACLE_HOME/cfgtoollogs/configToolAllCommands	\
					RESPONSE_FILE=/home/grid/grid_${db}.properties\""
}

function create_dg # $1 nom du DG
{
	typeset -r	DG=$1

	info "Create DG : $DG"
	IFS=':' read dg_name size first last<<<"$(cat $db_cfg_path/disks | grep "^${DG}")"
	total_disks=$(( $last - $first + 1 ))
	exec_cmd "ssh -t grid@${node_names[0]} \". .profile;	\
		~/plescripts/dg/create_new_dg.sh -name=$DG -disks=$total_disks\""
}

#	Création des DGs.
#	- Pour un serveur standalone création du DG FRA.
#	- Pour un serveur RAC création des DG DATA & FRA puis montage sur les autres nœuds.
function create_all_dgs
{
	line_separator

	# Pour le RAC uniquement, le premier DG étant CRS ou GRID
	[ $max_nodes -gt 1 ] && create_dg DATA || true

	create_dg FRA
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
	ssh_node0 root srvctl stop cvu
	ssh_node0 root srvctl disable cvu
	ssh_node0 root srvctl stop oc4j
	ssh_node0 root srvctl disable oc4j
}

function set_ASM_memory_target_low_and_restart_ASM
{
	if [ $hack_asm_memory != "0" ]
	then
		line_separator
		disclaimer
		exec_cmd "ssh grid@${node_names[0]} \". .profile;	\
				~/plescripts/database_servers/set_ASM_memory_target_low.sh\""
		LN

		if [ $max_nodes -gt 1 ]
		then	#	RAC
			ssh_node0 root crsctl stop cluster -all
			LN

			timing 5
			LN

			ssh_node0 root crsctl start cluster -all
		else	#	SINGLE
			ssh_node0 root srvctl stop asm -f
			LN

			timing 5
			LN

			ssh_node0 root srvctl start asm
		fi
		LN
	else
		info "do nothing : hack_asm_memory=0"
	fi
}

function remove_tfa_on_all_nodes
{
	line_separator
	disclaimer
	for (( i=0; i < max_nodes; ++i ))
	do
		exec_cmd -c ssh -t root@${node_names[i]} \
				". /root/.bash_profile \; tfactl uninstall"
		LN
	done
}

function add_scan_to_local_known_hosts
{
	typeset	-r scan_cfg="$cfg_path_prefix/$db/scanvips"
	typeset	scan
	typeset	vip1
	typeset	vip2
	typeset	vip3
	IFS=':' read scan vip1 vip2 vip3<<<"$(cat $scan_cfg)"

	typeset -r pub_key=$(ssh-keyscan -t ecdsa $scan | cut -d\  -f2-)

	exec_cmd "sed -i '/$scan/d' ~/.ssh/known_hosts"
	exec_cmd "echo '$scan,$vip1,$vip2,$vip3 $pub_key' >> ~/.ssh/known_hosts"
	LN
}

#	======================================================================
#	MAIN
#	======================================================================
script_start

line_separator
for (( inode = 1; inode <= max_nodes; ++inode ))
do
	load_node_cfg $inode
done

if [ $max_nodes -gt 1 ]
then
	exit_if_file_not_exists $db_cfg_path/scanvips
	typeset -r scan_name=$(cat $db_cfg_path/scanvips | cut -d: -f1)

	info "==> scan name     = $scan_name"
	info "==> clusterNodes  = $clusterNodes"
	LN
fi

if [ $oracle_home_for_test == no ]
then
	#	On doit récupérer l'ORACLE_HOME du grid qui est différent entre 1 cluster et 1 single.
	ORACLE_HOME=$(ssh grid@${node_names[0]} ". .bash_profile; env|grep ORACLE_HOME"|cut -d= -f2)
	ORACLE_BASE=$(ssh grid@${node_names[0]} ". .bash_profile; env|grep ORACLE_BASE"|cut -d= -f2)
else
	ORACLE_HOME=/$GRID_DISK/oracle_home/bidon
	ORACLE_BASE=/$GRID_DISK/oracle_base/bidon
fi

info "ORACLE_HOME = '$ORACLE_HOME'"
info "ORACLE_BASE = '$ORACLE_BASE'"
LN

[ x"$ORACLE_HOME" == x ] && error "Can't read ORACLE_HOME for user grid on ${node_names[0]}" && exit 1

if [ $skip_grid_install == no ]
then
	create_response_file $db_cfg_path/disks
	LN
	create_property_file
	LN
fi

[ $rsp_file_only == yes ] && exit 0	# Ne fait pas l'installation.

exec_cmd wait_server ${node_names[0]}
LN

stats_tt start grid_installation

if [ $skip_grid_install == no ]
then
	copy_response_and_properties_files
	LN
	mount_install_directory
	LN
	start_grid_installation
	LN
fi

[ $skip_root_scripts == no ] && run_post_install_root_scripts || true

if [ $skip_configToolAllCommands == no ]
then
	if [ $max_nodes -gt 1 ]
	then	#	RAC
		if [ $do_hacks == yes ]
		then
			[ $force_MGMTDB == yes ] && runConfigToolAllCommands && LN || true
			remove_tfa_on_all_nodes
			LN
			stop_and_disable_unwanted_grid_ressources
			LN
			set_ASM_memory_target_low_and_restart_ASM
			LN
			[ $force_MGMTDB == no ] && info "La base -MGMTDB n'est pas créée." && LN || true
		else
			runConfigToolAllCommands
		fi
	else	#	SINGLE
		runConfigToolAllCommands
		LN

		if [ $do_hacks == yes ]
		then
			set_ASM_memory_target_low_and_restart_ASM
			#Pour être certain qu'ASM est démarré.
			timing 30 "Wait grid"
			LN
		fi
	fi
fi

[ $skip_create_dg == no ] && create_all_dgs || true

[ $max_nodes -gt 1 ] && add_scan_to_local_known_hosts || true

stats_tt stop grid_installation

info "Installation status :"
ssh_node0 grid crsctl stat res -t
LN

script_stop $ME $db
LN

info "Oracle software can be installed."
info "./install_oracle.sh -db=$db"
LN
