#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset		db=undef
typeset -i	node=-1
typeset		vmGroup
typeset		update_os=no
typeset		vg_name=asm01

typeset		start_server_only=no
typeset		kvmclock=disable

add_usage "-db=name"			"Database name."
add_usage "[-vmGroup=name]"		"VBox group name."
add_usage "[-node=#]"           "For RAC server : node number."
add_usage "[-update_os]"		"Update OS."
add_usage "[-vg_name=$vg_name]"	"VG name to use on $infra_hostname"

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)

Debug flag :
	[-start_server_only] The server is cloned, only start it.
	[-keep_kvmclock]     For RAC, kvmclock is disabled.
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

		-keep_kvmclock)
			kvmclock=enable
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

ple_enable_log

script_banner $ME $*

exit_if_param_undef db 		"$str_usage"

cfg_exists $db

typeset -ri max_nodes=$(cfg_max_nodes $db)

# Pour un serveur standalone il n'est pas nécessaire de préciser le n° du nœud.
[[ $node -eq -1 && $max_nodes -eq 1 ]] && node=1 || true

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

	typeset db_type=rac
	if [ $max_nodes -eq 1 ]
	then
		[ $disk_type == FS ] && db_type=single_fs || db_type=single
	fi

	#	Source .bash_profile pour éviter les erreurs du script oracle_preinstall/02_install_some_rpms.sh
	#	Voir dans le script la section "NFS problem workaround"
	#	Note je ne sais pas si c'est efficace, c'est un teste.
	ssh_server ". .bash_profile;	\
					plescripts/oracle_preinstall/run_all.sh -db_type=$db_type"
	LN

	line_separator
	info "Create link for root user."
	ssh_server "ln -s plescripts/disk ~/disk"
	ssh_server "ln -s plescripts/yum ~/yum"
	LN

	info "Create link for grid user."
	ssh_server "ln -s /mnt/plescripts /home/grid/plescripts"
	ssh_server "ln -s /home/grid/plescripts/dg /home/grid/dg"
	LN

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

	sleep 2

	while [ 1 -eq 1 ]	# forever
	do
		wait_server $server
		if [ $? -ne 0 ]
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
	exec_cmd "$vm_scripts_path/reboot_vm $server -error_on_poweroff"
	LN

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
									/mnt/oracle_install nfs ro,defaults,noauto"

	ssh_server "sed -i '/oracle_install/d' /etc/fstab"
	ssh_server "[ ! -d /mnt/oracle_install ] &&	mkdir /mnt/oracle_install || true"
	ssh_server "echo '$fstab' >> /etc/fstab"
	ssh_server "mount /mnt/oracle_install"
	LN
}

#	Sur le premier nœud les disques doivent être crées puis exportés.
function create_san_LUNs_and_attach_to_node1
{
	line_separator
	info "Setup SAN"

	exec_cmd "ssh -t $san_conn											\
						plescripts/san/create_lun_for_db.sh				\
													-create_lv			\
													-vg_name=$vg_name	\
													-db=${db}			\
													-node=$node"
	LN

	ssh_server "plescripts/disk/discovery_target.sh"
	LN

	ssh_server "plescripts/disk/create_oracleasm_disks_on_new_disks.sh -db=$db"
	LN
}

#	Dans le cas d'un RAC les autres nœuds vont se connecter au portail et
#	appeler oracleasm pour accéder aux disques.
function attach_existing_LUNs_on_node
{
	line_separator
	info "Setup SAN"
	exec_cmd "ssh -t $san_conn	\
		plescripts/san/create_lun_for_db.sh -vg_name=$vg_name -db=${db} -node=$node"

	ssh_server "plescripts/disk/discovery_target.sh"
	ssh_server "oracleasm scandisks"
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

	if [ $disk_type != FS ]
	then
		info "Create mount point /$GRID_DISK for Grid"
		ssh_server plescripts/disk/create_fs.sh		\
						-mount_point=/$GRID_DISK	\
						-suffix_vglv=grid			\
						-type_fs=$rdbms_fs_type
		LN
	else
		info "Create database FS"
		ssh_server plescripts/disk/create_fs.sh		\
					-type_fs=$rdbms_fs_type			\
					-suffix_vglv=oradata			\
					-mount_point=/$GRID_DISK

	fi

	if [[ $max_nodes -eq 1 || $cfg_oracle_home == $rdbms_fs_type ]]
	then
		info "Create mount point /$ORCL_DISK for Oracle"
		ssh_server	plescripts/disk/create_fs.sh		\
							-mount_point=/$ORCL_DISK	\
							-suffix_vglv=orcl			\
							-type_fs=$rdbms_fs_type
		LN
	else
		info "Install ocfs2"
		ssh_server "yum -y -q install ocfs2-tools"
		LN

		ssh_server "~/plescripts/disk/create_cluster_ocfs2.sh -db=$db"
		LN

		typeset action=create
		[ $node -ne 1 ] && action=add || true
		ssh_server	plescripts/disk/create_fs_ocfs2.sh	\
							-db=$db						\
							-mount_point=/$ORCL_DISK	\
							-device=/dev/sdc			\
							-action=$action
		LN
	fi
}

#	Configure le master cloné
function configure_server
{
	if [ $node -eq 1 ] && [ $start_server_only == no ]
	then
		if [ $max_nodes -eq 1 ]
		then
			typeset -r vm_memory=$vm_memory_mb_for_single_db
		else
			typeset -r vm_memory=$vm_memory_mb_for_rac_db
		fi
		exec_cmd "$vm_scripts_path/clone_vm.sh	-db=$db						\
												-vm_memory_mb=$vm_memory	\
												-vmGroup=\"$vmGroup\""
		LN
		# VirtualBox Manager se met mal à jour, s'il est démarré je le relance.
		exec_cmd "restart_vboxmanager.sh"
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
	configure_ifaces_hostname_and_reboot

	#	************************************************************************
	#	Le serveur a sa configuration réseau définitive : $server_name.
	add_to_known_hosts $server_name
	LN

	line_separator
	make_ssh_equi_with_san

	line_separator
	info "Workaround yum error : [Errno 256] No more mirrors to try."
	ssh_server systemctl start nfs-mountd.service
	LN

	#	Si depuis la création du master le dépôt par défaut a changé, permet
	#	de basculer sur le bon dépôt.
	ssh_server ". .bash_profile; ~/plescripts/yum/switch_repo_to.sh -local"

	if [ $update_os == yes ]
	then
		test_if_rpm_update_available $server_name
		[ $? -eq 0 ] && ssh_server "yum -y -q update" || true
		LN
	fi

	create_disks_for_oracle_and_grid_softwares
}

#	Met en place tous les pré requis Oracle
function configure_oracle_accounts
{
	run_oracle_preinstall

	info "install bash completion for srvctl"
	fake_exec_cmd cd ~/plescripts/tmp
	cd ~/plescripts/tmp
	exec_cmd rm -f srvctl.bash
	exec_cmd -c wget https://raw.githubusercontent.com/PhilippeLeroux/oracle_bash_completion/master/srvctl.bash
	if [ $? -eq 0 ]
	then
		exec_cmd scp srvctl.bash root@$cfg_server_name:/etc/bash_completion.d/
	fi
	fake_exec_cmd cd -
	cd -
	LN

	ssh_server "plescripts/gadgets/customize_logon.sh"
	LN
}

function rac_configure_ntp
{
	info "RAC node : install & configure ntp."
	ssh_server "~/plescripts/ntp/configure_ntp.sh"
	LN

	info "Force sync time"
	ssh_server "crontab ~/plescripts/ntp/crontab_workaround_ntp.txt"
	LN

	if [ $kvmclock == disable ]
	then
		ssh_server "~/plescripts/ntp/disable_kvmclock.sh"
		LN
	fi
}

function copy_color_file
{
	line_separator
	info "Colors for light screen"
	typeset -r DIR_COLORS=~/plescripts/myconfig/suse_dir_colors
	exec_cmd "scp $DIR_COLORS root@$server_name:.dir_colors"
	exec_cmd "scp $DIR_COLORS grid@$server_name:.dir_colors"
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

	exec_cmd "ssh grid@$server_name \
		\"[ ! -d ~/.vim ]	\
			&& (gzip -dc ~/plescripts/myconfig/vim.tar.gz | tar xf -) || true\""

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

	if [ $max_nodes -gt 1 ]
	then
		ssh_server "plescripts/stats/create_service_ifrac_stats.sh"
	fi
	LN
}

function test_space_on_san
{
	typeset	-ri	total_disk_mb=$(to_mb $(cfg_total_disk_size_gb $db)G)
	typeset	-ri	san_free_space_mb=$(to_mb $(ssh $infra_conn LANG=C vgs $vg_name | tail -1 | awk '{ print $7 }'))

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

#	============================================================================
#	MAIN
#	============================================================================
script_start

cfg_load_node_info $db $node

typeset -r server_name=$cfg_server_name
typeset -r disk_type=$(cat $cfg_path_prefix/$db/disks | tail -1 | cut -d: -f1)

if [ $node -eq 1 ]
then
	[ $cfg_luns_hosted_by == san ] && test_space_on_san || true
else
	test_if_other_nodes_up
fi

configure_server

configure_oracle_accounts

#	Équivalence entre le virtual-host et le serveur de bdd
#	Permet depuis le virtual-host de se connecter sans mot de passe avec les
#	comptes root, grid et oracle.
exec_cmd "~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh	\
													-remote_server=$server_name"
LN

install_vim_plugin

copy_color_file

add_oracle_install_directory_to_fstab

case $cfg_luns_hosted_by in
	san)
		if [ $node -eq 1 ]
		then
			[ "$disk_type" != FS ] && create_san_LUNs_and_attach_to_node1 || true
		else
			attach_existing_LUNs_on_node
		fi
	;;

	vbox)
		if [ $node -eq 1 ]
		then
			if [ $disk_type != FS ]
			then
				ssh_server "plescripts/disk/create_oracleasm_disks_on_new_disks.sh -db=$db"
			fi
		else
			ssh_server "oracleasm scandisks"
		fi
	;;

	*)
		error "cfg_luns_hosted_by = '$cfg_luns_hosted_by' invalid."
		exit 1
esac

create_stats_services

#	Pour utiliser chrony définir la variable RAC_NTP=chrony
[[ $max_nodes -gt 1 && "$RAC_NTP" != chrony ]] && rac_configure_ntp || true

info "Reboot needed : new kernel config from oracle-rdbms-server-12cR1-preinstall"
reboot_server $server_name
LN

if [ $node -eq $max_nodes ]
then	# C'est le dernier nœud
	if [ $max_nodes -ne 1 ]
	then	# Plus de 1 nœud donc c'est un RAC.
		exec_cmd "~/plescripts/database_servers/apply_ssh_prereq_on_all_nodes.sh -db=$db"
		LN
	fi

	script_stop $ME $db

	if [ $disk_type == FS ]
	then
		info "The Oracle RDBMS software can be installed."
		info "./install_oracle.sh -db=$db"
	else
		info "The Grid infrastructure can be installed."
		info "./install_grid.sh -db=$db"
	fi
	LN
elif [ $max_nodes -ne 1 ]
then	# Ce n'est pas le dernier nœud et il y a plus de 1 nœud.
	script_stop $ME $db

	info "Run script :"
	info "$ME -db=$db -node=$(( node + 1 ))"
	LN
fi
