#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=<str>            Identifiant de la base.
	[-vmGroup=name]      Nom du group ou doit être enregistré la VM.
	[-node=<#>]          N° du nœud si base de type RAC.

	[-start_server_only] Le serveur est déjà cloné, uniquement le démarrer. (Util uniqement lors du debug)
"

script_banner $ME $*

typeset		db=undef
typeset -i	node=-1
typeset		vmGroup

typeset		start_server_only=no

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

		-pause=*)
			PAUSE=${1##*=}
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
			LN
			exit 1
			;;
	esac
done

exit_if_param_undef db 		"$str_usage"

cfg_exist $db

typeset -ri max_nodes=$(cfg_max_nodes $db)
[ $node -eq -1 ] && [ $max_nodes -eq 1 ] && node=1
exit_if_param_undef node	"$str_usage"

cfg_load_node_info $db $node
typeset -r server_name=$cfg_server_name

typeset -r disk_type=$(cat $cfg_path_prefix/$db/disks | tail -1 | cut -d: -f1)

typeset -r vg_name=asm01

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
	exec_cmd "ssh -t root@$server_name \". .bash_profile; plescripts/oracle_preinstall/run_all.sh $db_type\""
	LN

	line_separator
	info "Create link for root user."
	exec_cmd "ssh -t root@$server_name 'ln -s plescripts/disk ~/disk'"
	exec_cmd "ssh -t root@$server_name 'ln -s plescripts/yum ~/yum'"
	LN

	info "Create link for grid user."
	exec_cmd "ssh -t root@$server_name ln -s /mnt/plescripts /home/grid/plescripts"
	exec_cmd "ssh -t root@$server_name ln -s /home/grid/plescripts/dg /home/grid/dg"
	LN

	info "Create link for Oracle user."
	exec_cmd "ssh -t root@$server_name ln -s /mnt/plescripts /home/oracle/plescripts"
	exec_cmd "ssh -t root@$server_name ln -s /home/oracle/plescripts/db /home/oracle/db"
	LN

	info "Add grid & oracle accounts to group users (to read NFS mount points)."
	exec_cmd "ssh -t root@$server_name plescripts/database_servers/add_oracle_grid_into_group_users.sh"
	LN
}

#	$1 nom du serveur à attendre.
function loop_wait_server
{
	typeset -r server=$1

	sleep 2

	while [ 1 -eq 1 ]	# forever
	do
		~/plescripts/shell/wait_server $server
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
	exec_cmd "$vm_scripts_path/reboot_vm $server"
	LN

	loop_wait_server $server
	LN
}

function configure_ifaces_hostname_and_reboot
{
	info "Configure network..."
	exec_cmd "ssh -t $master_conn plescripts/configure_network/setup_iface_and_hostename.sh -db=$db -node=$node"
	LN

	#	Le reboot est nécessaire à cause du changement du nom du serveur.
	reboot_server $server_name
}

#	Nomme l'initiator
function setup_iscsi_inititiator
{
	info "Setup initiator name :"
	iscsi_initiator=$(get_initiator_for $db $node)
	exec_cmd "ssh -t root@$master_name \"echo InitiatorName=$iscsi_initiator > /etc/iscsi/initiatorname.iscsi\""
	LN
}

#	Monte le répertoire d'installation sur /mnt/oracle_install
function mount_oracle_install
{
	line_separator
	info "Mount point for Oracle installation"
	typeset fstab="$client_hostname:/home/$common_user_name/${oracle_install} /mnt/oracle_install nfs ro,defaults,noauto"

	exec_cmd "ssh -t root@${server_name} sed -i '/oracle_install/d' /etc/fstab"
	exec_cmd "ssh -t root@${server_name} \"[ ! -d /mnt/oracle_install ] && mkdir /mnt/oracle_install || true\""
	exec_cmd "ssh -t root@${server_name} \"echo $fstab >> /etc/fstab\""
	exec_cmd "ssh -t root@${server_name} mount /mnt/oracle_install"
	LN
}

#	Sur le premier noeud les disques doivent être crées puis exportés.
function create_san_LUNs_and_attach_to_node1
{
	line_separator
	info "Setup SAN"
	exec_cmd "ssh -t $san_conn plescripts/san/create_lun_for_db.sh -create_lv -vg_name=$vg_name -db=${db} -node=$node"
	LN

	exec_cmd "ssh -t root@${server_name} plescripts/disk/discovery_target.sh"
	exec_cmd "ssh -t root@${server_name} plescripts/disk/create_oracleasm_disks_on_new_disks.sh -db=$db"
}

#	Dans le cas d'un RAC les autres noeuds vont se connecter au portail et
#	appeler oracleasm pour accéder aux disques.
function attach_existing_LUNs_on_node
{
	line_separator
	info "Setup SAN"
	exec_cmd "ssh -t $san_conn plescripts/san/create_lun_for_db.sh -vg_name=$vg_name -db=${db} -node=$node"

	exec_cmd "ssh -t root@${server_name} plescripts/disk/discovery_target.sh"
	exec_cmd "ssh -t root@${server_name} oracleasm scandisks"
	LN
}

#	Attend que le serveur master soit actif.
function wait_master
{
	~/plescripts/shell/wait_server $master_name
	[ $? -ne 0 ] && exit 1
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
#	Note l'odre de création des FS est important, si OCFS2 est utilisé c'est le
#	disque sdc qui est partagé, sdb ne l'est jamais.
function create_disks_for_oracle_and_grid_softwares
{
	line_separator

	if [ $disk_type != FS ]
	then
		info "Create mount point /$GRID_DISK for Grid"
		exec_cmd ssh -t root@$server_name plescripts/disk/create_fs.sh		\
												-mount_point=/$GRID_DISK	\
												-suffix_vglv=grid			\
												-type_fs=$rdbms_fs_type
		LN
	else
		info "Create database FS"
		exec_cmd ssh -t root@${server_name} plescripts/disk/create_fs.sh	\
											-type_fs=$rdbms_fs_type			\
											-suffix_vglv=oradata			\
											-mount_point=/$GRID_DISK

	fi

	if [[ $max_nodes -eq 1 || $rac_orcl_fs == default ]]
	then
		info "Create mount point /$ORCL_DISK for Oracle"
		exec_cmd ssh -t root@$server_name plescripts/disk/create_fs.sh		\
												-mount_point=/$ORCL_DISK	\
												-suffix_vglv=orcl			\
												-type_fs=$rdbms_fs_type
		LN
	else
		info "Install ocfs2"
		exec_cmd  "ssh -t root@$server_name \"yum -y install ocfs2-tools\""
		LN

		exec_cmd ssh -t root@$server_name	\
						plescripts/disk/create_cluster_ocfs2.sh -db=$db
		LN

		typeset action=create
		[ $node -ne 1 ] && action=add
		exec_cmd ssh -t root@$server_name	\
						plescripts/disk/create_fs_ocfs2.sh	\
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
	fi

	#	-wait_os=no car le nom du serveur n'a pas encore été changé.
	exec_cmd "$vm_scripts_path/start_vm $server_name -wait_os=no"
	LN
	exec_cmd "wait_server $master_name"

	#	************************************************************************
	#	La VM a été clonée mais sa configuration réseau correspond toujours à
	#	celle du master, il faut donc régénérer la clef public.
	add_2_know_hosts $master_name
	LN

	line_separator
	register_server_2_dns

	line_separator
	setup_iscsi_inititiator

	line_separator
	configure_ifaces_hostname_and_reboot

	#	************************************************************************
	#	Le serveur a sa configuration réseau définitive : $server_name.
	add_2_know_hosts $server_name
	LN

	line_separator
	make_ssh_equi_with_san
	LN

	#	Correction problèmes Network Manager
	info "Remove bad ifaces."
	exec_cmd "ssh -t root@$server_name plescripts/nm_workaround/rm_conn_without_device.sh"
	LN

	line_separator
	test_if_rpm_update_available $server_name
	[ $? -eq 0 ] && exec_cmd "ssh -t root@$server_name \"yum -y update\""
	LN

	create_disks_for_oracle_and_grid_softwares
}

#	Met en place tous les pré requis Oracle
function configure_oracle_accounts
{
	run_oracle_preinstall

	exec_cmd "ssh -t root@$server_name plescripts/gadgets/install.sh"
	LN
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

#	Ne pas appeler pour le premier noeud d'un RAC.
#	Pour les autres noeuds (supérieur à 1 donc) test si le serveur précédent
#	à été configuré.
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

#	============================================================================
#	MAIN
#	============================================================================
script_start

[ $node -gt 1 ]	&& test_if_other_nodes_up

configure_server

configure_oracle_accounts

#	Equivalence entre le poste client/serveur host et le serveur de bdd
#	Permet depuis le poste client/serveur host de se connecter sans mot de passe
#	avec les comptes root, grid et oracle.
exec_cmd "~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh -remote_server=$server_name"

copy_color_file

mount_oracle_install

case $cfg_luns_hosted_by in
	san)
		if [ $node -eq 1 ]
		then
			[ "$disk_type" != FS ] && create_san_LUNs_and_attach_to_node1
		else
			attach_existing_LUNs_on_node
		fi
	;;

	vbox)
		if [ $node -eq 1 ]
		then
			if [ $disk_type != FS ]
			then
				exec_cmd "ssh -t root@${server_name} plescripts/disk/create_oracleasm_disks_on_new_disks.sh -db=$db"
			fi
		else
			exec_cmd "ssh -t root@${server_name} oracleasm scandisks"
		fi
	;;

	*)
		error "cfg_luns_hosted_by = '$cfg_luns_hosted_by' invalid."
		exit 1
esac

info "Plymouth theme."
exec_cmd -c "ssh -t root@$server_name plescripts/shell/set_plymouth_them"
LN

info "Enable stats."
exec_cmd "ssh -t root@${server_name} plescripts/stats/create_systemd_service_stats.sh"
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
then	# Ce n'est pas le dernier noeud et il y a plus de 1 noeud.
	script_stop $ME $db

	info "Run script :"
	info "$ME -db=$db -node=$(( node + 1 ))"
	LN
fi
