#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset		db=undef
typeset -i	node=1
typeset		vmGroup
typeset		update_os=no
typeset		vg_name=$infra_vg_name_for_db_luns
typeset		show_instructions=yes

typeset		start_server_only=no
typeset		kvmclock=$rac_kvmclock

add_usage "-db=name"			"Database name."
add_usage "[-vmGroup=name]"		"VBox group name."
add_usage "[-node=$node]"       "RAC & Dataguard server : node number."
add_usage "[-update_os]"		"Update OS."
add_usage "[-vg_name=$vg_name]"	"VG name to use on $infra_hostname"
add_usage "[-skip_instructions]" "Used by create_database_servers.sh"

typeset	-r	str_usage=\
"Usage :
$ME
$(print_usage)

Debug flag :
	[-start_server_only]    The server is cloned, only start it.
	[-kvmclock=$kvmclock]   For RAC : enable|disable kvmclock.
"

while [ $# -ne 0 ]
do
	case $1 in
		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-node=*)
			node=${1##*=}
			shift
			;;

		-vmGroup=*)
			vmGroup=${1##*=}
			shift
			;;

		-start_server_only)
			start_server_only=yes
			shift
			;;

		-kvmclock=*)
			kvmclock=$(to_lower ${1##*=})
			shift
			;;

		-update_os)
			update_os=yes
			shift
			;;

		-pause=*)
			PAUSE=${1##*=}
			shift
			;;

		-skip_instructions)
			show_instructions=no
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
			LN
			exit 1
			;;
	esac
done

ple_enable_log -params $PARAMS

exit_if_param_undef db 		"$str_usage"

cfg_exists $db

typeset -ri max_nodes=$(cfg_max_nodes $db)

exit_if_param_undef node	"$str_usage"

#	Exécute, via ssh, la commande '$@' sur le master
function ssh_master
{
	exec_cmd "ssh -t root@$master_hostname '$@'"
}

#	Exécute, via ssh, la commande '$@' sur le serveur de BDD
function ssh_server
{
	if [ "$1" == "-c" ]
	then
		typeset	-r farg="-c"
		shift
	else
		typeset	-r farg
	fi

	exec_cmd $farg "ssh -t root@$server_name '$@'"
}

# Fabrique le nom du groupe ou sera placée la VM
# Le script clone_vm.sh ajoutera le slash.
function make_vmGroup
{
	case $cfg_db_type in
		std|fs)
			if [ $cfg_dataguard == yes ]
			then
				vmGroup="DG $(initcap $db)"
			else
				vmGroup="Single $(initcap $db)"
			fi
			;;

		rac)
			vmGroup="RAC $(initcap $db)"
			# RAC + standby non pris en compte.
			;;
	esac

	case "$cfg_orarel" in
		12.1*)
			vmGroup="$vmGroup 12cR1"
			;;
		12.2*)
			vmGroup="$vmGroup 12cR2"
			;;
	esac
}

function register_server_2_dns
{
	info "Register server to DNS"
	exec_cmd "~/plescripts/configure_network/setup_dns.sh -db=$db -node=$node"
	LN
}

function run_oracle_preinstall
{
	line_separator
	info "Run oracle preinstall..."

	case $cfg_db_type in
		std)
			typeset -r db_type=single
			;;
		fs)
			typeset -r db_type=single_fs
			;;
		rac)
			typeset -r db_type=rac
			;;
	esac

	ssh_server ". .bash_profile;	\
					plescripts/oracle_preinstall/run_all.sh -db_type=$db_type"
	LN

	line_separator
	info "Create link for root user."
	ssh_server "ln -s plescripts/disk ~/disk"
	ssh_server "ln -s plescripts/yum ~/yum"
	LN

	if [ $db_type != single_fs ]
	then
		info "Create link for grid user."
		ssh_server "ln -s /mnt/plescripts /home/grid/plescripts"
		ssh_server "ln -s /home/grid/plescripts/dg /home/grid/dg"
		LN
	fi

	info "Create link for Oracle user."
	ssh_server "ln -s /mnt/plescripts /home/oracle/plescripts"
	ssh_server "ln -s /home/oracle/plescripts/db /home/oracle/db"
	LN

	info "Add grid & oracle accounts to group users (to read NFS mount points)."
	ssh_server "~/plescripts/database_servers/add_oracle_grid_into_group_users.sh"
	LN
}

#	$1 nom du serveur à attendre.
function loop_wait_server
{
	typeset -r server=$1

	timing 10

	while true	# forever
	do
		if ! wait_server $server
		then
			error "Cannot contact $server"
			LN
			info "Press a key to retry or ctrl-c to abort."
			read keyboard
			LN
		else
			return 0
		fi
	done
}

#	$1 nom du serveur à rebooter.
function reboot_server
{
	typeset -r server=$1

	info "Reboot server $server..."
	exec_cmd "$vm_scripts_path/reboot_vm $server -error_on_poweroff -lsvms=no"

	loop_wait_server $server
}

function configure_ifaces_hostname_and_reboot
{
	info "Configure network..."
	ssh_master "~/plescripts/configure_network/setup_iface_and_hostname.sh	\
														-db=$db -node=$node"
	LN

	# Le reboot est nécessaire à cause du changement du nom du serveur et de
	# son IP.
	reboot_server $server_name
	LN

	#	Pour que le serveur cloné et le serveur master n'aient pas la même
	#	HWaddress.
	info "Clearing arp cache."
	#	Ne pas utiliser arp -d sinon le cache des autres serveurs n'est pas mis
	#	à jour.
	exec_cmd sudo ip -s -s neigh flush all
	LN
}

#	Nomme l'initiator
function setup_iscsi_inititiator
{
	info "Setup initiator name :"
	iscsi_initiator=$(get_initiator_for $db $node)
	ssh_master "echo InitiatorName=$iscsi_initiator > /etc/iscsi/initiatorname.iscsi"
	LN
}

#	Monte le répertoire d'installation sur /mnt/oracle_install
function add_oracle_install_directory_to_fstab
{
	line_separator
	info "Mount point for Oracle installation"
	typeset fstab="$client_hostname:/home/$common_user_name/${oracle_install}	\
									/mnt/oracle_install nfs ro,$ro_nfs_options,noauto"

	ssh_server "sed -i '/oracle_install/d' /etc/fstab"
	ssh_server "[ ! -d /mnt/oracle_install ] &&	mkdir /mnt/oracle_install || true"
	ssh_server "echo '$fstab' >> /etc/fstab"
	ssh_server "mount /mnt/oracle_install"
	LN
}

# 1 create LUNs on SAN
# 2 export LUNs to bdd server
# 3 register LUNs on bdd server
function create_and_export_san_LUNs
{
	line_separator
	info "Create LUNs on $infra_hostname"

	exec_cmd "ssh -t $san_conn											\
						plescripts/san/create_lun_for_db.sh				\
													-create_lv			\
													-vg_name=$vg_name	\
													-db=${db}			\
													-node=$node"
	LN

	ssh_server "plescripts/disk/discovery_target.sh"
	LN
}

# 2 export existing LUNs to bdd server
# 3 register LUNs on bdd server
function export_SAN_LUNs
{
	line_separator
	info "Export LUN on $infra_hostname"
	exec_cmd "ssh -t $san_conn	\
		plescripts/san/create_lun_for_db.sh -vg_name=$vg_name -db=${db} -node=$node"
	LN

	ssh_server "plescripts/disk/discovery_target.sh"
	LN
}

function create_database_fs_on_new_disks
{
	typeset -r cfg_disks=$cfg_path_prefix/$db/disks

	#http://docs.oracle.com/database/122/VLDBG/vldb-storage.htm#VLDBG1600
	typeset -ri stripesize_kb=1024

	IFS=':' read name size_disk first last<<<"$(grep FSDATA $cfg_disks)"
	info "Create FS for DATA"
	ssh_server plescripts/disk/create_fs.sh						\
							-disks=$(( last - first + 1 ))		\
							-mount_point=/$ORCL_DATA_FS_DISK	\
							-suffix_vglv=oradata				\
							-type_fs=$rdbms_fs_type				\
							-striped=yes						\
							-stripesize=$stripesize_kb			\
							-netdev

	ssh_server "chown oracle:oinstall /$ORCL_DATA_FS_DISK"
	ssh_server "chmod 775 /$ORCL_DATA_FS_DISK"
	LN

	IFS=':' read name size_disk first last<<<"$(grep FSFRA $cfg_disks)"
	info "Create FS for FRA"
	ssh_server plescripts/disk/create_fs.sh						\
							-disks=$(( last - first + 1 ))		\
							-mount_point=/$ORCL_FRA_FS_DISK		\
							-suffix_vglv=orafra					\
							-type_fs=$rdbms_fs_type				\
							-striped=yes						\
							-stripesize=$stripesize_kb			\
							-netdev

	ssh_server "chown oracle:oinstall /$ORCL_FRA_FS_DISK"
	ssh_server "chmod 775 /$ORCL_FRA_FS_DISK"
	LN
}

function create_oracleasm_disks_on_new_disks
{
	ssh_server "plescripts/disk/create_oracleasm_disks_on_new_disks.sh	\
															-db=$db"
	LN
}

#	Permet au compte root du serveur de se connecter sur le SAN sans mot de passe.
#	N'utilise pas make_ssh_user_equivalence_with.sh car il nécessite la saisie du
#	mots de passe root.
function make_ssh_equi_with_san
{
	exec_cmd "~/plescripts/ssh/setup_ssh_equivalence.sh	\
						-user1=root						\
						-server1=$san_hostname			\
						-server2=$server_name"
}

#	Création des disques et points de montages pour l'installation des logiciels
#	Oracle & Grid
#	Note l'ordre de création des FS est important, si OCFS2 est utilisé c'est le
#	disque sdc qui est partagé, sdb ne l'est jamais.
function create_disks_for_oracle_and_grid_softwares
{
	line_separator

	if [ $cfg_db_type == fs ]
	then
		info "Create database FS"
		ssh_server plescripts/disk/create_fs.sh		\
					-type_fs=$rdbms_fs_type			\
					-suffix_vglv=orcl				\
					-mount_point=/$ORCL_SW_FS_DISK	\
					-noatime
		LN
		return 0
	fi

	info "Create mount point /$GRID_DISK for Grid"
	ssh_server plescripts/disk/create_fs.sh		\
					-mount_point=/$GRID_DISK	\
					-suffix_vglv=grid			\
					-type_fs=$rdbms_fs_type		\
					-noatime
	LN

	if [[ $cfg_db_type == rac && $cfg_oracle_home == ocfs2 ]]
	then
		info "Install CLVM & ocfs2"
		ssh_server "yum -y -q install lvm2-cluster ocfs2-tools"
		LN

		info "Enable cluster LVM"
		ssh_server "lvmconf --enable-cluster"
		LN

		ssh_server "~/plescripts/disk/create_cluster_ocfs2.sh -db=$db"
		LN

		typeset action=create
		[ $node -ne 1 ] && action=add || true
		ssh_server	plescripts/disk/create_fs_ocfs2.sh	\
							-cluster_name=$db			\
							-mount_point=/$ORCL_DISK	\
							-suffix_vglv=orcl			\
							-action=$action
		LN
	else # single + Grid Infra.
		info "Create mount point /$ORCL_DISK for Oracle"
		ssh_server	plescripts/disk/create_fs.sh		\
							-mount_point=/$ORCL_DISK	\
							-suffix_vglv=orcl			\
							-type_fs=$cfg_oracle_home	\
							-noatime
		LN
	fi
}

#	Configure le master cloné
function configure_server
{
	if [[ $node -eq 1 || $cfg_dataguard == yes ]] && [[ $start_server_only == no ]]
	then
		if [[ $cfg_db_type != rac ]]
		then
			typeset -r vm_memory=$vm_memory_mb_for_single_db
		else
			typeset -r vm_memory=$vm_memory_mb_for_rac_db
		fi
		exec_cmd "$vm_scripts_path/clone_vm.sh	-db=$db						\
												-node=$node					\
												-vm_memory_mb=$vm_memory	\
												-vmGroup=\"$vmGroup\""
		LN
	fi

	#	-wait_os=no car le nom du serveur n'a pas encore été changé.
	exec_cmd "$vm_scripts_path/start_vm $server_name -wait_os=no -dataguard=no"

	exec_cmd "wait_server $master_hostname"

	#	************************************************************************
	#	La VM a été clonée mais sa configuration réseau correspond toujours à
	#	celle du master, il faut donc régénérer la clef public.
	add_to_known_hosts $master_hostname

	line_separator
	register_server_2_dns

	line_separator
	setup_iscsi_inititiator

	line_separator
	if [ $workaround_yum_error_256 == apply ]
	then
		info "Workaround yum error : [Errno 256] No more mirrors to try."
		ssh_master systemctl start nfs-mountd.service
		LN
	fi

	#	Si depuis la création du master le dépôt par défaut a changé, permet
	#	de basculer sur le bon dépôt.
	ssh_master ". .bash_profile;						\
					~/plescripts/yum/switch_repo_to.sh	\
							-local -release=$orcl_yum_repository_release"

	line_separator
	configure_ifaces_hostname_and_reboot

	#	************************************************************************
	#	Le serveur a sa configuration réseau définitive : $server_name.
	add_to_known_hosts $server_name
	LN

	line_separator
	make_ssh_equi_with_san

	line_separator
	ssh_server "plescripts/journald/enable_persistent_storage_for_syslog.sh"

	create_disks_for_oracle_and_grid_softwares

	if [[ $update_os == yes ||
			$infra_yum_repository_release != $orcl_yum_repository_release ]]
	then
		if rpm_update_available $server_name
		then
			ssh_server "yum -y -q install gperftools-libs"
			ssh_server "export LD_PRELOAD=\"/usr/lib64/libtcmalloc_minimal.so.4\" && yum -y -q update"
		fi
		LN
	fi
}

#	Met en place tous les pré requis Oracle
function configure_oracle_accounts
{
	if [ $cfg_db_type != fs ]
	then
		if ! ping_test github.com
		then
			warning "github.com not available."
			LN
		else
			typeset -r srvctl_script="srvctl_${oracle_release%.*.*}.bash"
			info "install bash completion for srvctl"
			typeset -r BACKUP_PWD="$PWD"
			fake_exec_cmd "cd ~/plescripts/tmp"
			cd ~/plescripts/tmp
			exec_cmd rm -f $srvctl_script
			exec_cmd -c wget https://raw.githubusercontent.com/PhilippeLeroux/oracle_bash_completion/master/$srvctl_script
			if [ $? -eq 0 ]
			then
				exec_cmd scp	$srvctl_script	\
								root@$cfg_server_name:/etc/bash_completion.d/
			fi
			fake_exec_cmd "cd -"
			cd -
			LN
		fi
	fi

	ssh_server "plescripts/gadgets/customize_logon.sh"
	LN
}

function rac_configure_ntp
{
	info "RAC node : install & configure ntp."
	ssh_server "~/plescripts/ntp/configure_ntp.sh"
	LN

	if [ $rac_forcesyncntp == yes ]
	then
		info "Force sync time"
		ssh_server "crontab ~/plescripts/ntp/crontab_workaround_ntp.txt"
		LN
	else
		info "Force sync time not applied."
		LN
	fi

	if [ $kvmclock == disable ]
	then
		ssh_server "~/plescripts/grub2/setup_kernel_boot_options.sh -add=\"no-kvmclock no-kvmclock-vsyscall\""
		LN
	else
		info "kvmclock not disabled."
		LN
	fi
}

function disable_cgroup_memory
{
	line_separator
	info "Disable cgroup for memory"
	ssh_server "~/plescripts/grub2/setup_kernel_boot_options.sh -add=\"cgroup_disable=memory\""
	LN
}

function enable_kernel
{
	line_separator
	info "Enable kernel $ol7_kernel_version"
	LN

	if [ "$ol7_kernel_version" == redhat ]
	then
		ssh_server "~/plescripts/grub2/enable_redhat_kernel.sh -skip_test_infra"
		LN
	else
		ssh_server "~/plescripts/grub2/enable_oracle_kernel.sh -version=$ol7_kernel_version"
		LN
	fi
}

# Cette action est faite sur le master, elle n'est plus activée probablement
# après l'application du rpm des précos Oracle.
# Donc réactivation de l'option.
function disable_console_blanking
{
	line_separator
	info "Disable console blanking"
	ssh_server '~/plescripts/grub2/setup_kernel_boot_options.sh -add="consoleblank=0"'
	LN
}

function copy_color_file
{
	line_separator
	info "Colors for light screen"
	typeset -r DIR_COLORS=~/plescripts/myconfig/suse_dir_colors
	exec_cmd "scp $DIR_COLORS root@$server_name:.dir_colors"
	if [ $cfg_db_type != fs ]
	then
		exec_cmd "scp $DIR_COLORS grid@$server_name:.dir_colors"
	fi
	exec_cmd "scp $DIR_COLORS oracle@$server_name:.dir_colors"
	LN
}

#	Ne pas appeler pour le premier nœud d'un RAC.
#	Pour les autres nœuds (supérieur à 1 donc) test si le serveur précédent
#	à été configuré.
#	BUG : ne fonctionne pas avec plus de 2 nœuds.
function test_if_other_nodes_up
{
	typeset check_ok=yes

	for node_file in ~/plescripts/database_servers/$db/node*
	do
		typeset other_node=$(cat $node_file | cut -d: -f2)
		if [ $other_node != $server_name ]
		then
			info -n "Test if $other_node is up : "
			nc $other_node 22 </dev/null >/dev/null 2>&1
			if [ $? -ne 0 ]
			then
				info -f "[$KO]"
				check_ok=no
			else
				info -f "[$OK]"
			fi
			LN
		fi
	done

	[ $check_ok == no ] && exit 1 || true
}

function install_vim_plugin
{
	info "Install VIM plugins."

	if [ $cfg_db_type != fs ]
	then
		exec_cmd "ssh grid@$server_name \
		\"[ ! -d ~/.vim ]	\
			&& (gzip -dc ~/plescripts/myconfig/vim.tar.gz | tar xf -) || true\""
	fi

	exec_cmd "ssh oracle@$server_name	\
		\"[ ! -d ~/.vim ]	\
			&& (gzip -dc ~/plescripts/myconfig/vim.tar.gz | tar xf -) || true\""
	LN
}

function create_stats_services
{
	info -n "Create services stats"
	case $PLESTATISTICS in
		*)
			info -f ", services not enabled."
			;;

		ENABLE)
			info -f " and enable them."
	esac

	ssh_server "plescripts/stats/create_service_memory_stats.sh"

	ssh_server "plescripts/stats/create_service_ifpub_stats.sh"

	ssh_server "plescripts/stats/create_service_ifiscsi_stats.sh"

	ssh_server "plescripts/stats/create_service_uptime_stats.sh"

	if [[ $cfg_db_type == rac ]]
	then
		ssh_server "plescripts/stats/create_service_ifrac_stats.sh"
	fi
	LN
}

function test_space_on_san
{
	typeset	-ri	total_disk_mb=$(to_mb $(cfg_total_disk_size_gb $db)G)
	typeset	-ri	san_free_space_mb=$(to_mb $(ssh $infra_conn LANG=C vgs --unit G $vg_name | tail -1 | awk '{ print $7 }'))

	info -n "Server $db needs $(fmt_number $total_disk_mb)Mb of disk, available on $infra_hostname $(fmt_number $san_free_space_mb)Mb : "
	if [ $total_disk_mb -gt $san_free_space_mb ]
	then
		info -f "$KO"
		error "Not enought disk available."
		LN
		exit 1
	fi
	info -f "$OK"
	LN
}

function bug_rac122_workaround
{
	if [[ $cfg_db_type == rac || $cfg_orarel == 12.2.0.1 ]]
	then
		line_separator
		info "Information dans l'en-tête du script...."
		LN
		ssh_server "cp plescripts/grub2/orclbug_switch_kernel.sh /root"
		LN
	fi
}

#	============================================================================
#	MAIN
#	============================================================================

[ $show_instructions == yes ] || script_start || true

cfg_load_node_info $db $node

if [ "$cfg_orarel" != "${oracle_release}" ]
then
	warning "Bad Oracle Release"
	exec_cmd ~/plescripts/update_local_cfg.sh ORACLE_RELEASE=$cfg_orarel

	info "Rerun with local config updated."
	exec_cmd $ME $PARAMS
	LN
	exit 0
fi

typeset -r server_name=$cfg_server_name

[ x"$vmGroup" == x ] && make_vmGroup || true

if [ $node -eq 1 ]
then
	[ $cfg_luns_hosted_by == san ] && test_space_on_san || true
else
	test_if_other_nodes_up
fi

configure_server

add_oracle_install_directory_to_fstab

run_oracle_preinstall

configure_oracle_accounts

#	----------------------------------------------------------------------------
# Toujours modifier les paramètres kernel après les préco Oracle qui ne tiennent
# pas compte des nouveaux paramètres et les désactives.
[ $cgroup_memory == disable ] && disable_cgroup_memory || true

[ "$ol7_kernel_version" != latest ] && enable_kernel || true

[ $console_blanking == disable ] && disable_console_blanking || true
#	----------------------------------------------------------------------------

#	Équivalence entre le virtual-host et le serveur de bdd
#	Permet depuis le virtual-host de se connecter sans mot de passe avec les
#	comptes root, grid et oracle.
[ $cfg_db_type == fs ] && arg="-no_grid_user" || true
exec_cmd "~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh	\
						-remote_server=$server_name $arg"
LN

install_vim_plugin

copy_color_file

bug_rac122_workaround

if [[ $node -eq 1 || $cfg_dataguard == yes ]]
then
	[ $cfg_luns_hosted_by == san ] && create_and_export_san_LUNs || true

	if [ $cfg_db_type != fs ]
	then
		if [[ "$device_persistence" == "oracleasm" ]]
		then
			create_oracleasm_disks_on_new_disks
		fi
	else
		create_database_fs_on_new_disks
	fi
else
	[ $cfg_luns_hosted_by == san ] && export_SAN_LUNs || true

	if [[ "$device_persistence" == "oracleasm" ]]
	then
		ssh_server "oracleasm scandisks"
	fi
	# A partir de la 12.2 se fait lors de l'installation du grid (AFD).
fi

create_stats_services

[ $cfg_db_type == rac ] && rac_configure_ntp || true

exec_cmd reboot_vm $server_name
LN

loop_wait_server $server_name
LN

if [ "$install_guestadditions" == yes ]
then
	fake_exec_cmd cd ~/plescripts/virtualbox/guest
	cd ~/plescripts/virtualbox/guest
	exec_cmd "./test_guestadditions.sh -host=$server_name -y"
	fake_exec_cmd cd -
	cd -
	LN
fi

script_stop $ME $db
LN

if [ $node -eq $max_nodes ]
then	# C'est le dernier nœud
	if [[ $cfg_db_type == rac ]]
	then
		exec_cmd "~/plescripts/database_servers/apply_ssh_prereq_on_all_nodes.sh -db=$db"
		LN
	fi

	if [ $show_instructions == yes ]
	then
		if [ $cfg_db_type == fs ]
		then
			notify "Oracle RDBMS software can be installed."
			info "./install_oracle.sh -db=$db"
		else
			if [ "${oracle_release}" == "12.2.0.1" ]
			then
				script_name=install_grid12cR2.sh
			else
				script_name=install_grid12cR1.sh
			fi
			notify "Grid infrastructure can be installed."
			info "./$script_name -db=$db"
		fi
		LN
	fi
elif [[ $cfg_db_type == rac && $show_instructions == yes ]]
then
	notify "Server cloned."
	info "Run script :"
	info "$ME -db=$db -node=$(( node + 1 ))"
	LN
fi
