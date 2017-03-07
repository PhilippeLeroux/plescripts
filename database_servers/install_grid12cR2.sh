#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=name

Debug flag :
	-skip_extract_grid
	-skip_init_afd_disks
	-skip_install_grid
	-skip_create_dg_fra
"

typeset db=undef
typeset	extract_grid_image=yes
typeset	init_afd_disks=yes
typeset	install_grid=yes
typeset create_dg_fra=yes

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

		-skip_extract_grid)
			extract_grid_image=no
			shift
			;;

		-skip_init_afd_disks)
			init_afd_disks=no
			shift
			;;

		-skip_install_grid)
			install_grid=no
			shift
			;;

		-skip_create_dg_fra)
			create_dg_fra=no
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

exit_if_param_undef db	"$str_usage"

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

function make_disk_list
{
	typeset -r disk_cfg_file="$1"

	#	Les disques sont numérotés à partir de 1, donc le n° du dernier disque
	#	correspond au nombre de disques.
	typeset	-ri	total_disks=$(head -1 $disk_cfg_file | cut -d: -f4)

	ssh root@${node_names[0]} "plescripts/disk/get_unused_disks.sh -count=$total_disks"
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
		typeset disk_list=$(make_disk_list $disk_cfg_file)
		update_value oracle.install.asm.diskGroup.disks				"$disk_list"	$rsp_file
		disk_list=$(sed "s/,/,,/g"<<<"$disk_list")
		update_value oracle.install.asm.diskGroup.disksWithFailureGroupNames "${disk_list}," $rsp_file
		update_value oracle.install.asm.diskGroup.diskDiscoveryString "/dev/sd\*"	$rsp_file
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

function copy_response_and_properties_files
{
	line_separator
	info "Response file   : $rsp_file"
	info "Copy files to ${node_names[0]}:/home/grid/"
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

function start_grid_installation
{
	line_separator
	info "Start grid installation (~3mn)."
	add_dynamic_cmd_param "LANG=C ./gridSetup.sh"
	add_dynamic_cmd_param "      -waitforcompletion"
	add_dynamic_cmd_param "      -responseFile /home/grid/grid_$db.rsp"
	add_dynamic_cmd_param "      -silent\""
	exec_dynamic_cmd -c "ssh -t grid@${node_names[0]} \"cd $ORACLE_HOME &&"
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
	info "Run post install scripts on node #${nr_node} $server_name (~3mn)"
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

function executeConfigTools
{
	line_separator
	info "Execute config tools (~3mn)"
	add_dynamic_cmd_param "$ORACLE_HOME/gridSetup.sh"
	add_dynamic_cmd_param "-executeConfigTools"
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

function disclaimer
{
	info "****************************************************"
	info "* Not supported by Oracle Corporation              *"
	info "* For personal use only, on a desktop environment. *"
	info "****************************************************"
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
			ssh_node0 root crsctl stop has
			LN

			timing 5
			LN

			ssh_node0 root crsctl start has
		fi
		LN
	else
		info "do nothing : hack_asm_memory=0"
	fi
}

script_start

cfg_exists $db

typeset -r db_cfg_path=$cfg_path_prefix/$db

#	Nom du "fichier réponse" pour l'installation du grid
typeset -r rsp_file=${db_cfg_path}/grid_$db.rsp

#	Nom du  "fichier propriété" utilisé pour ConfigTool
typeset -r prop_file=${db_cfg_path}/grid_$db.properties

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

if [ x"$ORACLE_HOME" == x ]
then
	error "Can't read ORACLE_HOME for user grid on ${node_names[0]}"
	exit 1
fi

mount_install_directory

if [ $extract_grid_image == yes ]
then
	line_separator
	info "Extract Grid Infra image (~2mn)"
	ssh_node0 grid "cd $ORACLE_HOME && unzip -q /mnt/oracle_install/grid/linuxx64_12201_grid_home.zip"
	LN
fi

if [ $init_afd_disks == yes ]
then
	create_response_file $db_cfg_path/disks

	copy_response_and_properties_files

	line_separator
	info "Init AFD disks"
	ssh_node0 root "~/plescripts/disk/root_init_afd_disks.sh -db=$db"
	LN
fi

if [ $install_grid == yes ]
then
	start_grid_installation
	run_post_install_root_scripts_on_node 1 ${node_names[0]}
	executeConfigTools
fi

if [ $create_dg_fra == yes ]
then
	create_dg FRA
fi

set_ASM_memory_target_low_and_restart_ASM

timing 30 "Wait CRS"
LN

script_stop $ME $db
LN

info "Oracle software can be installed."
info "./install_oracle.sh -db=$db"
LN
