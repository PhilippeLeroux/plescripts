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
	-db=name      Identifiant de la base
	[-keep_tfa]   RAC ne pas supprimer tfa

Debug flags :
	-reponse_file_only
	-skip_extract_grid
	-skip_init_afd_disks   reponse file is created at this step.
	-skip_reponse_file     work only with -skip_init_afd_disks
	-skip_install_grid
	-skip_post_install     configTools and hacks.
	-skip_create_dg

	Par défaut des hacks sont fait pour diminuer la consommation mémoire :
		* Réduction de la mémoire ASM
		* Arrêt de certains services.
		* Suppression de tfa
		* La base MGMTDB n'est pas crées.
	Le flag -no_hacks permet de ne pas mettre en œuvre ces hacks.
	Le flag -force_MGMTDB force l'installation de la base en conservant les autres hacks.
	Note l'installation de GIMR (MGMTDB) échoue systématiquement.

	-oracle_home_for_test permet de tester le script sans que les VMs existent.
"

typeset db=undef
typeset keep_tfa=no
typeset	extract_grid_image=yes
typeset	init_afd_disks=yes
typeset	create_reponse_file=yes
typeset	install_grid=yes
typeset	post_install=yes
typeset create_dg=yes
typeset	reponse_file_only=no
typeset	oracle_home_for_test=no
typeset	do_hacks=yes
typeset force_MGMTDB=no

# L'option n'existe pas encore.
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

		-keep_tfa)
			keep_tfa=yes
			shift
			;;

		-reponse_file_only)
			reponse_file_only=yes
			shift
			;;

		-oracle_home_for_test)
			oracle_home_for_test=yes
			shift
			;;

		-skip_extract_grid)
			extract_grid_image=no
			shift
			;;

		-skip_init_afd_disks)
			init_afd_disks=no
			shift
			;;

		-skip_reponse_file)
			create_reponse_file=no
			shift
			;;

		-skip_install_grid)
			install_grid=no
			shift
			;;

		-skip_post_install)
			post_install=no
			shift
			;;

		-skip_create_dg)
			create_dg=no
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

ple_enable_log -params $PARAMS

exit_if_param_undef db	"$str_usage"

#	$1 optional -c
#	$1 or $2 account name
#	Execute on node 0 (node_names[0]) command "$@" (except first arg)
function ssh_node0
{
	if [ "$1" == "-c" ]
	then
		typeset -r farg="-c"
		shift
	else
		typeset -r farg
	fi
	typeset -r account=$1
	shift
	exec_cmd $farg "ssh -t ${account}@${node_names[0]} \". .bash_profile; $@\""
}

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

	if [ x"$clusterNodes" = x ]
	then
		clusterNodes=$cfg_server_name:${cfg_server_name}-vip:HUB
	else
		clusterNodes=$clusterNodes,$cfg_server_name:${cfg_server_name}-vip:HUB
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

# $1 disks file conf
# $2 dg name
function make_disk_list
{
	typeset -r disk_cfg_file="$1"

	typeset		dg_name
	typeset	-i	dg_size
	typeset	-i	dg_first_nr
	typeset	-i	dg_last_nr
	IFS=':' read dg_name dg_size dg_first_nr dg_last_nr<<<"$(cat $disk_cfg_file | grep "$2")"

	typeset	-i	total_disks=$(( dg_last_nr - dg_first_nr + 1 ))

	((--dg_first_nr))
	ssh root@${node_names[0]} "plescripts/disk/get_unused_disks.sh -count=$total_disks -skip_disks=$dg_first_nr"
}

# $1 nom du fichier décrivant les disques
function create_response_file
{
	typeset -r disk_cfg_file="$1"

	line_separator
	info "Create $rsp_file for grid installation."
	exit_if_file_not_exists template_grid_${oracle_release%.*.*}.rsp
	exec_cmd cp -f template_grid_${oracle_release%.*.*}.rsp $rsp_file
	LN

	#update_value ORACLE_HOSTNAME							${node_names[0]}	$rsp_file
	update_value ORACLE_BASE								$ORACLE_BASE		$rsp_file
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
		update_value oracle.install.asm.storageOption				ASM				$rsp_file
		typeset disk_list=$(make_disk_list $disk_cfg_file DATA)
		update_value oracle.install.asm.diskGroup.disks				"$disk_list"	$rsp_file
		disk_list=$(sed "s/,/,,/g"<<<"$disk_list")
		update_value oracle.install.asm.diskGroup.disksWithFailureGroupNames "${disk_list}," $rsp_file
		update_value oracle.install.asm.diskGroup.diskDiscoveryString "/dev/sd\*"	$rsp_file
	else
		update_value oracle.install.option						CRS_CONFIG				$rsp_file
		update_value oracle.install.asm.diskGroup.name			CRS						$rsp_file
		update_value oracle.install.asm.diskGroup.redundancy	EXTERNAL				$rsp_file
		update_value oracle.install.crs.config.gpnp.scanName	$scan_name				$rsp_file
		update_value oracle.install.crs.config.gpnp.scanPort	1521					$rsp_file
		update_value oracle.install.crs.config.clusterName		$scan_name				$rsp_file
		update_value oracle.install.crs.config.clusterNodes		$clusterNodes			$rsp_file

		typeset	pub_network=$(right_pad_ip $if_pub_network)
		typeset	rac_network=$(right_pad_ip $if_rac_network)
		typeset	iscsi_network=$(right_pad_ip $if_iscsi_network)
		typeset nil=$if_pub_name:${pub_network}:1,$if_rac_name:${rac_network}:5,$if_iscsi_name:${iscsi_network}:3
		update_value oracle.install.crs.config.networkInterfaceList $nil				$rsp_file
		update_value oracle.install.crs.config.storageOption	empty					$rsp_file
		typeset disk_list=$(make_disk_list $disk_cfg_file CRS)
		update_value oracle.install.asm.diskGroup.disks			"$disk_list"			$rsp_file
		disk_list=$(sed "s/,/,,/g"<<<"$disk_list")
		update_value oracle.install.asm.diskGroup.disksWithFailureGroupNames "${disk_list}," $rsp_file
		update_value oracle.install.asm.diskGroup.diskDiscoveryString "/dev/sd\*"		$rsp_file
		update_value oracle.install.asm.gimrDG.AUSize			4						$rsp_file

		update_value oracle.install.asm.configureGIMRDataDG		true					$rsp_file
		update_value oracle.install.asm.gimrDG.name				GIMR					$rsp_file
		update_value oracle.install.asm.gimrDG.redundancy		EXTERNAL				$rsp_file
		typeset disk_list=$(make_disk_list $disk_cfg_file GIMR)
		update_value oracle.install.asm.gimrDG.disks			$disk_list				$rsp_file
		disk_list=$(sed "s/,/,,/g"<<<"$disk_list")
		update_value oracle.install.asm.gimrDG.disksWithFailureGroupNames "${disk_list}," $rsp_file
		update_value oracle.install.asm.configureAFD			true					$rsp_file
	fi
	LN
}

function copy_response_file
{
	line_separator
	info "Response file   : $rsp_file"
	info "Copy file to ${node_names[0]}:/home/grid/"
	exec_cmd "scp $rsp_file grid@${node_names[0]}:/home/grid/"
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
	info "Start grid installation (${extract_grid_mn[idx_mn]})."
	add_dynamic_cmd_param "LANG=C ./gridSetup.sh"
	add_dynamic_cmd_param "      -waitforcompletion"
	# Ne pas utiler $rsp_file
	add_dynamic_cmd_param "      -responseFile /home/grid/grid_$db.rsp"
	add_dynamic_cmd_param "      -silent\""
	exec_dynamic_cmd -c "ssh -t grid@${node_names[0]} \"cd $ORACLE_HOME &&"
	if [[ $? -gt 250 || $? -eq 127 ]]
	then
		restore_swappiness

		error "Look log, if ntp sync failed re-run the script and"
		error "add options -skip_extract_grid -skip_init_afd_disks"
		LN
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
}

function run_post_install_root_scripts_on_node	# $1 node# $2 server_name
{
	typeset	-ri	nr_node=$1
	typeset	-r	server_name=$2

	line_separator
	info -n "Run post install scripts on node #${nr_node} $server_name"
	if [ $nr_node -eq 1 ]
	then
		info -f " ${post_install_root_script_node1_mn[idx_mn]}"
	else
		info -f " ${post_install_root_script_other_node_mn[idx_mn]}"
	fi
	LN

	exec_cmd -novar "ssh -t root@$server_name	\
				\"${ORACLE_BASE%/*/*}/app/oraInventory/orainstRoot.sh\""
	LN

	exec_cmd -c -novar "ssh -t -t root@$server_name \". .bash_profile;	\
											$ORACLE_HOME/root.sh\""
	ret=$?
	LN
	return $ret
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
				exit 1
			fi
		fi

		if [[ $keep_tfa == no && $max_nodes -gt 1 ]]
		then
			info "Uninstall TFA on node $node_name"
			exec_cmd ssh "root@${node_name} '. .bash_profile; tfactl uninstall'"
			LN
		fi

		if [[ $max_nodes -gt 1 && $inode -eq 0 ]]
		then
			timing 10
			LN
		fi
	done
}

function executeConfigTools
{
	line_separator
	info "Execute config tools (${configtools[idx_mn]})"
	add_dynamic_cmd_param "$ORACLE_HOME/gridSetup.sh"
	add_dynamic_cmd_param "-executeConfigTools"
	# Ne pas utiler $rsp_file
	add_dynamic_cmd_param "-responseFile /home/grid/grid_$db.rsp"
	add_dynamic_cmd_param "-silent\""
	exec_dynamic_cmd "ssh grid@${node_names[0]} \". .bash_profile &&"
	LN
}

function create_dg # $1 nom du DG
{
	typeset -r	DG=$1

	line_separator
	info "Create DG : $DG"
	IFS=':' read dg_name size first last<<<"$(cat $db_cfg_path/disks | grep "^${DG}")"
	total_disks=$(( $last - $first + 1 ))
	exec_cmd "ssh -t grid@${node_names[0]} \". .profile;	\
		~/plescripts/dg/create_new_dg.sh -name=$DG -disks=$total_disks\""
	LN
}

#	Création des DGs.
#	- Pour un serveur standalone création du DG FRA.
#	- Pour un serveur RAC création des DG DATA & FRA puis montage sur les autres nœuds.
function create_all_dgs
{
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

function restart_rac_cluster
{
	ssh_node0 root crsctl stop cluster -all
	LN

	# Parfois le second nœud est trop chargé et ne répond pas.
	# Arrêt du CRS sur les 2 nœuds :
	for node_name in ${node_names[*]}
	do
		exec_cmd "ssh root@${node_name} '. .bash_profile && crsctl stop crs'"
		LN
	done

	timing 5
	LN

	for node_name in ${node_names[*]}
	do
		exec_cmd "ssh root@${node_name} '. .bash_profile && crsctl start crs'"
		LN
	done
	LN

	#Pour être certain qu'ASM est démarré.
	timing 180 "Waiting cluster"
	LN
}

function restart_standalone_crs
{
	ssh_node0 root crsctl stop has
	LN

	timing 5
	LN

	ssh_node0 root crsctl start has
	LN

	#Pour être certain qu'ASM est démarré.
	timing 30 "Waiting cluster"
	LN
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

		[ $max_nodes -gt 1 ] && restart_rac_cluster || restart_standalone_crs
	else
		info "do nothing : hack_asm_memory=0"
	fi
}

function stop_and_disable_unwanted_grid_ressources
{
	line_separator
	disclaimer
	ssh_node0 root srvctl stop cvu
	ssh_node0 root srvctl disable cvu
	ssh_node0 root srvctl stop qosmserver
	ssh_node0 root srvctl disable qosmserver
}

#http://www.usn-it.de/index.php/2017/06/20/oracle-rac-12-2-high-load-on-cpu-from-gdb-when-node-missing/
function rac_disable_diagsnap
{
	if [ "$rac12cR2_diagsnap" == disable ]
	then
		# Normalement sur un seul nœud sa suffit.
		line_separator
		info "Disable diagsnap"
		LN

		for (( inode = 0; inode < max_nodes; ++inode ))
		do
			exec_cmd "ssh -t grid@${node_names[inode]} \". .bash_profile && oclumon manage -disable diagsnap\""
			LN
		done
	fi
}

# Dans la log du CRS un message apparait disant d'exécuter d'installer un
# driver compatible.
function rac_install_acfs_driver
{
	line_separator
	info "Install ACFS driver"
	LN

	for (( inode = 0; inode < max_nodes; ++inode ))
	do
		exec_cmd "ssh -t root@${node_names[inode]} \". .bash_profile && acfsroot install\""
		LN
	done
}

function post_installation
{
	if [ $max_nodes -gt 1 ]
	then	#	RAC
		if [ $do_hacks == yes ]
		then
			rac_disable_diagsnap
			[ $force_MGMTDB == yes ] && executeConfigTools && LN || true
			stop_and_disable_unwanted_grid_ressources
			LN
			set_ASM_memory_target_low_and_restart_ASM
			LN
			if [ $force_MGMTDB == no ]
			then
				info "La base -MGMTDB n'est pas créée."
				LN
			fi
		else
			executeConfigTools
		fi
		rac_install_acfs_driver
	else	#	SINGLE
		executeConfigTools
		LN

		if [ $do_hacks == yes ]
		then
			set_ASM_memory_target_low_and_restart_ASM
		fi
	fi
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
	done
}

script_start

stats_tt start grid_installation

cfg_exists $db

typeset -r db_cfg_path=$cfg_path_prefix/$db

#	Nom du "fichier réponse" pour l'installation du grid
typeset -r rsp_file=${db_cfg_path}/grid_$db.rsp

typeset -a	node_names
typeset -a	node_ips
typeset -a	node_vip_names
typeset -a	node_vips
typeset -a	node_iscsi_names
typeset -a	node_iscsi_ips
typeset -ri	max_nodes=$(cfg_max_nodes $db)

line_separator
for (( inode = 1; inode <= max_nodes; ++inode ))
do
	load_node_cfg $inode
done

typeset -ra extract_grid_mn=( "~2mn", "~2mn" )
typeset -ra grid_installion_mn=( "~3mn", "~12mn" )
typeset -ra post_install_root_script_node1_mn=( "~3mn", "~22mn" )
typeset -ra post_install_root_script_other_node_mn=( "~3mn", "~10mn" )
typeset -ra configtools=( "~3mn", "~50mn" )

if [ $max_nodes -gt 1 ]
then
	typeset -ri	idx_mn=1
	exit_if_file_not_exists $db_cfg_path/scanvips
	typeset -r scan_name=$(cat $db_cfg_path/scanvips | cut -d: -f1)

	info "==> scan name     = $scan_name"
	info "==> clusterNodes  = $clusterNodes"
	LN
else
	typeset -ri	idx_mn=0
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

if [ x"$ORACLE_HOME" == x ]
then
	error "Can't read ORACLE_HOME for user grid on ${node_names[0]}"
	exit 1
fi

if [ $reponse_file_only == yes ]
then
	create_response_file $db_cfg_path/disks
	exit 0
fi

mount_install_directory

if [ $extract_grid_image == yes ]
then
	line_separator
	info "Extract Grid Infra image (${extract_grid_mn[idx_mn]})"
	ssh_node0 -c grid "test -f $ORACLE_HOME/gridSetup.sh"
	if [ $? -eq 0 ]
	then
		warning "Grid Infra extracted, unzip skipped."
		LN
	else
		ssh_node0 grid "cd $ORACLE_HOME && unzip -q /mnt/oracle_install/grid/linuxx64_12201_grid_home.zip"
		LN
	fi
fi

if [ $init_afd_disks == yes ]
then
	if [ $create_reponse_file == yes ]
	then
		ssh_node0 -c grid "test -f $rsp_file"
		if [ $? -eq 0 ]
		then
			warning "Create response file skipped."
			LN
		else
			create_response_file $db_cfg_path/disks
			copy_response_file
		fi
	fi

	line_separator
	info "Init AFD disks"
	ssh_node0 root "~/plescripts/disk/root_init_afd_disks.sh -db=$db"
	LN
elif [ $create_reponse_file == no ]
then
	warning "Flag -skip_reponse_file invalid without -skip_init_afd_disks"
fi

if [ $install_grid == yes ]
then
	if [ $max_nodes -ne 1 ]
	then
		line_separator
		for node in ${node_names[*]}
		do
			exec_cmd "ssh -t root@${node} '~/plescripts/ntp/test_synchro_ntp.sh -max_loops=100'"
			LN
		done
	fi

	start_grid_installation

	run_post_install_root_scripts
fi

[ $post_install == yes ] && post_installation || true

[ $create_dg == yes ] && create_all_dgs || true

[ $max_nodes -gt 1 ] && add_scan_to_local_known_hosts || true

setup_ohasd_service

stats_tt stop grid_installation

info "Installation status :"
ssh_node0 grid crsctl stat res -t
LN

script_stop $ME $db
LN

notify "Oracle software can be installed."
info "./install_oracle.sh -db=$db"
LN
