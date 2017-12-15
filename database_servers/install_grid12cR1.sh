#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-db=name       Database ID
	[-dg_node=#]   Dataguard node number 1 or 2
	[-keep_tfa]    RAC keep tfa

Debug flags :
	Pour passer certaine phases de l'installation :
	   -rsp_file_only Uniquement créer le fichier réponse, pas d'installation.
	   -skip_grid_install
	   -skip_root_scripts
	   -skip_configToolAllCommands
	   -skip_create_dg

	Par défaut des hacks sont fait pour diminuer la consommation mémoire :
	    * Réduction de la mémoire ASM
	    * Arrêt de certains services.
		* Désactivation de tfa.
	    * La base mgmtdb et son listener sont désactivés.
	Le flag -no_hacks permet de ne pas mettre en œuvre ces hacks.

	-oracle_home_for_test permet de tester le script sans que les VMs existent.
"

typeset		db=undef
typeset	-i	dg_node=-1	# Ne doit être définie que pour un membre d'un dataguard.
typeset		keep_tfa=no
typeset		rsp_file_only=no

typeset		skip_grid_install=no
typeset		skip_root_scripts=no
typeset		skip_configToolAllCommands=no
typeset		skip_create_dg=no
typeset		do_hacks=yes

typeset		oracle_home_for_test=no

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

		-dg_node=*)
			dg_node=${1##*=}
			shift
			;;

		-keep_tfa)
			keep_tfa=yes
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

# Premier paramète -c facultatif
# $1 server name
function test_ntp_synchro_on_server
{
	if [ "$1" == "-c" ]
	then
		typeset p="-c"
		shift
	else
		typeset p=""
	fi
	exec_cmd $p "ssh -t root@$1 '~/plescripts/ntp/test_synchro_ntp.sh'"
	ret=$?
	LN
	return $ret
}

function test_ntp_synchro_all_servers
{
	line_separator
	for node in ${node_names[*]}
	do
		test_ntp_synchro_on_server -c $node
		if [ $? -ne 0 ]
		then
			warning "After VBox reboot execute :"
			info "$ME -skip_extract_grid -skip_init_afd_disks"
			LN
		fi
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

# $1 fichier décrivant les disques
function create_response_file
{
	typeset -r disk_cfg_file="$1"

	line_separator
	info "Create $rsp_file for grid installation."
	exit_if_file_not_exists template_grid_${oracle_release%.*.*}.rsp
	exec_cmd cp -f template_grid_${oracle_release%.*.*}.rsp $rsp_file
	LN

	update_variable ORACLE_HOSTNAME							${node_names[0]}	$rsp_file
	update_variable ORACLE_BASE								$ORACLE_BASE		$rsp_file
	update_variable ORACLE_HOME								$ORACLE_HOME		$rsp_file
	update_variable INVENTORY_LOCATION						${ORACLE_BASE%/*/*}/app/oraInventory	$rsp_file
	update_variable oracle.install.asm.SYSASMPassword		$oracle_password	$rsp_file
	update_variable oracle.install.asm.monitorPassword		$oracle_password	$rsp_file

	if [ $cfg_db_type != rac ]
	then
		update_variable oracle.install.option							HA_CONFIG		$rsp_file
		update_variable oracle.install.asm.diskGroup.name				DATA			$rsp_file
		update_variable oracle.install.asm.diskGroup.redundancy			EXTERNAL		$rsp_file
		update_variable oracle.install.crs.config.gpnp.scanName			empty			$rsp_file
		update_variable oracle.install.crs.config.gpnp.scanPort			empty			$rsp_file
		update_variable oracle.install.crs.config.clusterName			empty			$rsp_file
		update_variable oracle.install.crs.config.clusterNodes			empty			$rsp_file
		update_variable oracle.install.crs.config.networkInterfaceList	empty			$rsp_file
		update_variable oracle.install.crs.config.storageOption			empty			$rsp_file
		update_variable oracle.install.asm.diskGroup.disks $(make_disk_list $disk_cfg_file) $rsp_file
	else
		update_variable oracle.install.option						CRS_CONFIG			$rsp_file
		update_variable oracle.install.asm.diskGroup.name			CRS					$rsp_file
		update_variable oracle.install.crs.config.gpnp.scanName		$scan_name			$rsp_file
		update_variable oracle.install.crs.config.gpnp.scanPort		1521				$rsp_file
		update_variable oracle.install.crs.config.clusterName		$scan_name			$rsp_file
		update_variable oracle.install.crs.config.clusterNodes		$clusterNodes		$rsp_file

		typeset	pub_network=$(right_pad_ip $if_pub_network)
		typeset	rac_network=$(right_pad_ip $if_rac_network)
		typeset nil=$if_pub_name:${pub_network}:1,$if_rac_name:${rac_network}:2
		update_variable oracle.install.crs.config.networkInterfaceList $nil				$rsp_file
		update_variable oracle.install.crs.config.storageOption	LOCAL_ASM_STORAGE		$rsp_file
		update_variable oracle.install.asm.diskGroup.disks $(make_disk_list $disk_cfg_file) $rsp_file
	fi
	LN
}

function create_property_file
{
	info "Create property file ConfigTool : $prop_file"
	(	echo "oracle.assistants.asm|S_ASMPASSWORD=$oracle_password"
		echo "oracle.assistants.asm|S_ASMMONITORPASSWORD=$oracle_password"
	)	>  $prop_file
	LN
}

function copy_response_and_properties_files
{
	line_separator
	info "Response file   : $rsp_file"
	info "Properties file : $prop_file"
	info "Copy files to ${node_names[0]}:/home/grid/"
	exec_cmd "scp $rsp_file $prop_file grid@${node_names[0]}:/home/grid/"
	LN
}

function mount_install_directory
{
	line_separator
	info "Mount install directory :"
	exec_cmd -c "ssh root@${node_names[0]} mount /mnt/oracle_install"
	LN
}

# $1 server
function check_oracle_size
{
	typeset -r server=$1

	exec_cmd "ssh grid@$server '. .bash_profile && plescripts/database_servers/check_bin_oracle_size.sh'"
}

function start_grid_installation
{
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
	info "Start grid installation (~12mn)."
	add_dynamic_cmd_param "\"LANG=C /mnt/oracle_install/grid/runInstaller"
	add_dynamic_cmd_param "      -silent"
	add_dynamic_cmd_param "      -showProgress"
	add_dynamic_cmd_param "      -waitforcompletion"
	add_dynamic_cmd_param "      -responseFile /home/grid/grid_$db.rsp\""
	exec_dynamic_cmd -c "ssh -t grid@${node_names[0]}"

	if [[ $? -gt 250 || $? -eq 127 ]]
	then
		restore_swappiness

		error "To check errors :"
		error "cd /mnt/oracle_install/grid"
		error "Run : ./runcluvfy.sh stage -pre crsinst -fixup -n $(echo ${node_names[*]} | tr [:space:] ',')"
		exit 1
	fi
	LN

	line_separator
	for node in ${node_names[@]}
	do
		ssh grid@$node ". .bash_profile && echo 'SQLNET.INBOUND_CONNECT_TIMEOUT=300' > \$TNS_ADMIN/sqlnet.ora"
	done
	LN

	restore_swappiness

	check_oracle_size ${node_names[0]}
	LN
}

# $1 node# $2 server_name
function run_post_install_root_scripts_on_node
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
	info "Manual workaround, execute :"
	LN

	info "From $node_name :"
	info "$ ssh root@${node_name}"
	info "$ $ORACLE_HOME/root.sh"
	info "$ exit"
	LN

	info "From $client_hostname :"
	info "$ ./install_grid12cR1.sh -db=$db -skip_grid_install -skip_root_scripts"
	LN
}

function run_post_install_root_scripts
{
	typeset -i inode
	for (( inode=0; inode < max_nodes; ++inode ))
	do
		typeset node_name=${node_names[inode]}

		[ $cfg_db_type == rac ] && test_ntp_synchro_on_server $node_name || true
		LN

		run_post_install_root_scripts_on_node $((inode+1)) $node_name
		typeset -i ret=$?
		LN

		if [ $ret -ne 0 ]
		then
			# L'erreur se produit quand la synchronisation du temps est mauvaise.
			# Les erreurs de synchronisation varient bcps entre les diverses
			# versions de mon OS et de VirtualBox.
			#
			# Pour valider que le problème vient bien de la synchro du temps, voir
			# le fichier /tmp/force_sync_ntp.DD, si il y a bcp de resynchronisation
			# c'est que le temps sur le serveur fait des sauts.

			error "root scripts on server $node_name failed."
			[ $inode -eq 0 ] && exit 1 || true

			LN
			warning "Workaround :"
			LN

			[ $cfg_db_type == rac ] && test_ntp_synchro_on_server $node_name || true
			LN

			run_post_install_root_scripts_on_node 1 ${node_names[0]}
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
		[[ $cfg_db_type != rac ]] && break || true
	done
}

# Création de la base : -MGMTDB pour un RAC.
function runConfigToolAllCommands
{
	line_separator
	info "Run ConfigTool"
	LN

	[ $cfg_db_type == rac ] && test_ntp_synchro_all_servers || true

	exec_cmd -c "ssh -t grid@${node_names[0]}							\
				\"LANG=C $ORACLE_HOME/cfgtoollogs/configToolAllCommands	\
					RESPONSE_FILE=/home/grid/grid_${db}.properties\""
	LN

	if [[ $cfg_db_type == rac && $mgmtdb_create == yes && "$do_hacks" == yes && "$mgmtdb_autostart" == disable ]]
	then
		line_separator
		info "Disable and stop database mgmtdb."
		for node in ${node_names[*]}
		do # Il faut absolument désactiver sur tous les nœuds.
			ssh_node0 root srvctl disable mgmtlsnr -node $node
			LN
			ssh_node0 root srvctl disable mgmtdb -node $node
			LN
		done

		ssh_node0 grid srvctl stop mgmtdb -force
		LN
		ssh_node0 grid srvctl stop mgmtlsnr -force
		LN
	fi
}

# $1 nom du DG
function create_dg
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
	[ $cfg_db_type == rac ] && create_dg DATA || true

	create_dg FRA
}

function disclaimer
{
	info "*****************************"
	info "* Workstation configuration *"
	info "*****************************"
}

function stop_and_disable_unwanted_grid_ressources
{
	line_separator
	disclaimer
	ssh_node0 root srvctl stop cvu
	ssh_node0 root srvctl disable cvu
	ssh_node0 root srvctl stop oc4j
	ssh_node0 root srvctl disable oc4j
	LN
}

function set_ASM_memory_target_low_and_restart_ASM
{
	if [ "$asm_allow_small_memory_target" == "yes" ]
	then
		line_separator
		disclaimer
		exec_cmd "ssh grid@${node_names[0]} \". .profile;	\
				~/plescripts/database_servers/set_ASM_memory_target_low.sh\""
		LN

		if [ $cfg_db_type == rac ]
		then	#	RAC
			ssh_node0 root crsctl stop cluster -all
			LN

			timing 5
			LN

			ssh_node0 root crsctl start cluster -all
			LN
		else	#	SINGLE
			ssh_node0 root srvctl stop asm -f
			LN

			timing 5
			LN

			ssh_node0 root srvctl start asm
			LN
		fi
	else
		info "do nothing : asm_allow_small_memory_target = $asm_allow_small_memory_target"
		LN
	fi
}

function disable_tfa
{
	line_separator
	info "Stop and disable TFA on nodes ${node_names[*]}"
	for node_name in ${node_names[*]}
	do
		exec_cmd "ssh -t root@$node_name \". .bash_profile; tfactl stop && tfactl disable\""
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

function setup_ohasd_service
{
	line_separator
	typeset -i inode=0
	for (( inode=0; inode < max_nodes; ++inode ))
	do
		typeset node_name=${node_names[inode]}
		info "ohasd : iSCSI dependency on server $node_name"
		exec_cmd "ssh -t root@${node_name} plescripts/database_servers/setup_ohasd_service.sh"
		LN
		[ $cfg_db_type != rac ] && break || true
	done
}

function post_installation
{
	if [ $skip_configToolAllCommands == no ]
	then
		if [ $cfg_db_type == rac ]
		then
			if [ $do_hacks == yes ]
			then
				[ "$mgmtdb_create" == yes ] && runConfigToolAllCommands || true

				stop_and_disable_unwanted_grid_ressources

				set_ASM_memory_target_low_and_restart_ASM

				[ "$mgmtdb_create" == no ] && info "La base -MGMTDB n'est pas créée." && LN || true
			else
				runConfigToolAllCommands
			fi
		else	#	SINGLE
			runConfigToolAllCommands

			if [ $do_hacks == yes ]
			then
				set_ASM_memory_target_low_and_restart_ASM
				#Pour être certain qu'ASM est démarré.
				timing 30 "Wait grid"
				LN
			fi
		fi
	fi
}

#	======================================================================
#	MAIN
#	======================================================================
script_start

line_separator
if [ $dg_node -eq -1 ]
then
	for (( inode = 1; inode <= max_nodes; ++inode ))
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

if [ $cfg_db_type == rac ]
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

	create_property_file
fi

[ $rsp_file_only == yes ] && exit 0	# Ne fait pas l'installation.

exec_cmd wait_server ${node_names[0]}
LN

stats_tt start grid_installation

if [ $skip_grid_install == no ]
then
	copy_response_and_properties_files

	mount_install_directory

	[ $cfg_db_type == rac ] && test_ntp_synchro_all_servers || true

	start_grid_installation
fi

[ $skip_root_scripts == no ] && run_post_install_root_scripts || true

[[ $keep_tfa == no && $cfg_db_type == rac ]] && disable_tfa || true

post_installation

[ $skip_create_dg == no ] && create_all_dgs || true

[ $cfg_db_type == rac ] && add_scan_to_local_known_hosts || true

setup_ohasd_service

stats_tt stop grid_installation

info "Installation status :"
ssh_node0 grid crsctl stat res -t
LN

script_stop $ME $db
LN

if [[ $cfg_dataguard == yes ]]
then
	if [[ $dg_node -eq 1 ]]
	then
		notify "Grid infrastructure can be installed on second member."
		info "$ME -db=$db -dg_node=2"
		LN
	else
		notify "Oracle software can be installed."
		info "./install_oracle.sh -db=$db -dg_node=1"
		LN
	fi
else
	notify "Oracle software can be installed."
	info "./install_oracle.sh -db=$db"
	LN
fi
