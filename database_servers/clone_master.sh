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
	-db=<str>            identifiant de la base
	[-vmGroup=name]
	[-node=<#>]          n° du nœud si base de type RAC

	[-start_server_only] le serveur est cloné mais n'est pas démarré, utile que pour le nœud 1.
"

info "Running : $ME $*"

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

typeset -ri max_nodes=$(cfg_max_nodes $db)
[ $node -eq -1 ] && [ $max_nodes -eq 1 ] && node=1
exit_if_param_undef node	"$str_usage"

cfg_load_node_info $db $node
typeset -r server_name=$cfg_server_name

typeset -r disk_type=$(cat ~/plescripts/database_servers/$db/disks | tail -1 | cut -d: -f1)

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

	exec_cmd "ssh -t root@$server_name plescripts/oracle_preinstall/run_all.sh $db_type"
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
	exec_cmd "ssh -t $master_conn plescripts/configure_network/setup_iface_and_hostename.sh -db=$db -node=$node; exit"
	LN

	reboot_server $server_name

	test_pause "$server_name : Check network configuration."
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
	case $type_shared_fs in
		nfs)
			fstab="$client_hostname:/home/$common_user_name/${oracle_install} /mnt/oracle_install nfs ro,$nfs_options,noauto"
			;;

		vbox)
			fstab="${oracle_release%.*.*} /mnt/oracle_install vboxsf defaults,_netdev 0 0"
			;;
	esac

	exec_cmd "ssh -t root@${server_name} sed -i '/oracle_install/d' /etc/fstab"
	exec_cmd "ssh -t root@${server_name} \"[ ! -d /mnt/oracle_install ] && mkdir /mnt/oracle_install || true\""
	exec_cmd "ssh -t root@${server_name} \"echo $fstab >> /etc/fstab\""
	exec_cmd "ssh -t root@${server_name} mount /mnt/oracle_install"
	LN
}

#	Création du point de montage /u01/app/oracle/oradata
#		* Recherche un disque disponible
#		* Création du vg vgoradata et du lv lvoradate
#		* Pour création d'un FS du type rdbms_fs_type (cf global.cfg)
function create_rdbms_fs
{
	exec_cmd ssh -t root@${server_name} plescripts/disk/create_fs.sh		\
										-type_fs=$rdbms_fs_type				\
										-suffix_vglv=oradata				\
										-mount_point=/u01/app/oracle/oradata
	exec_cmd ssh -t root@${server_name} chown -R oracle:oinstall /u01/app/oracle
	LN
}

#	Sur le premier noeud les disques doivent être crées puis exportés.
function configure_disks_node1
{
	line_separator
	info "Setup SAN"
	exec_cmd "ssh -t $san_conn plescripts/san/create_lun_for_db.sh -create_lv -vg_name=$vg_name -db=${db} -node=$node"
	LN

	exec_cmd "ssh -t root@${server_name} plescripts/disk/discovery_target.sh"
	if [ $disk_type != FS ]
	then
		exec_cmd "ssh -t root@${server_name} plescripts/disk/create_oracleasm_disks_on_new_disks.sh -db=$db"
	else
		create_rdbms_fs
	fi
}

#	Dans le cas d'un RAC les autres noeuds vont se connecter au portail et
#	appeler oracleasm pour accéder aux disques.
function configure_disks_other_node_than_1
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
	typeset -r san_public_key=$(get_public_key_for $san_hostname)
	typeset -r san_public_key_escaped=$(escape_slash "$san_public_key")

	#	-c nécessaire si ~/.ssh/known_hosts n'existe pas
	#	Ajoute la clef public du serveur SAN dans le known_hosts du serveur.
	exec_cmd -c "ssh -t root@$server_name \"sed -i '/${san_public_key_escaped}/d' ~/.ssh/known_hosts 1>/dev/null\""
	exec_cmd "ssh -t root@$server_name \"echo \\\"$san_public_key\\\" >> ~/.ssh/known_hosts\""
	LN

	#	Création de la clef public pour le compte root.
	exec_cmd "ssh -t root@$server_name \"[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -N \\\"\\\" -f ~/.ssh/id_rsa\" || true"
	LN

	typeset -r public_key_file=id_rsa_${server_name}.pub
	#	Copie la clef de root du serveur en local.
	exec_cmd "scp root@$server_name:/root/.ssh/id_rsa.pub /tmp/$public_key_file"
	#	Copie le clef local vers le SAN.
	exec_cmd "scp /tmp/$public_key_file root@$san_hostname:/root/.ssh/$public_key_file"
	exec_cmd "rm /tmp/$public_key_file"
	#	Comme ça pas besoin de mot de passe, la clef et sur le serveur SAN.
	LN

	#	Fais le ménage au cas ou ...
	exec_cmd -c "ssh root@$san_hostname sed -i '/$server_name/d' /root/.ssh/authorized_keys"
	LN

	#	Ajoute la clef dans les autorisées.
	exec_cmd "ssh root@$san_hostname \"cat /root/.ssh/$public_key_file >> /root/.ssh/authorized_keys\""
	LN

	#	La clef peut être supprimée du serveur.
	exec_cmd "ssh root@$san_hostname rm /root/.ssh/$public_key_file"
	LN
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
		exec_cmd "$vm_scripts_path/clone_vm.sh -db=$db -vm_memory_mb=$vm_memory -vmGroup=\"$vmGroup\""
	fi

	exec_cmd "$vm_scripts_path/start_vm $server_name"
	wait_master

	#	************************************************************************
	#	La VM a été clonée mais sa configuration réseau correspond toujours à
	#	celle du master, il faut donc régénérer la clef public.
	add_2_know_hosts $master_name

	line_separator
	test_if_rpm_update_available $master_name
	[ $? -eq 0 ] && exec_cmd "ssh -t root@$master_name \"yum -y update\""
	LN

	line_separator
	info "Create mount point /u01"
	exec_cmd ssh -t root@$master_name plescripts/disk/create_fs.sh	\
											-mount_point=/u01		\
											-suffix_vglv=orcl		\
											-type_fs=xfs
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
}

#	Met en place tous les pré requis Oracle
function configure_oracle_accounts
{
	run_oracle_preinstall

	exec_cmd "~/plescripts/ssh/make_ssh_equi_with_all_users_of.sh -remote_server=$server_name"

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

	for node_file in $cfg_path/node*
	do
		typeset other_node=$(cat $node_file | cut -d: -f2)
		if [ $other_node != $server_name ]
		then
			info -n "Test if $other_node is up : "
			nc $other_node 22 </dev/null >/dev/null 2>&1
			if [ $? -ne 0 ]
			then
				info -f "$KO"
				check_ok=no
			else
				info -f "$OK"
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

copy_color_file

mount_oracle_install

case $cfg_luns_hosted_by in
	san)
		if [ $node -eq 1 ]
		then
			configure_disks_node1
		else
			configure_disks_other_node_than_1
		fi
	;;

	vbox)
		if [ $node -eq 1 ]
		then
			if [ $disk_type != FS ]
			then
				exec_cmd "ssh -t root@${server_name} plescripts/disk/create_oracleasm_disks_on_new_disks.sh -db=$db"
			else
				create_rdbms_fs
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

reboot_server $server_name
LN

if [ $type_shared_fs == vbox ]
then
	exec_cmd "$vm_scripts_path/compile_guest_additions.sh -host=$server_name"
fi

if [ $node -eq $max_nodes ]
then	# C'est le dernier nœud
	if [ $max_nodes -ne 1 ]
	then	# Plus de 1 nœud donc c'est un RAC.
		exec_cmd "~/plescripts/database_servers/apply_ssh_prereq_on_all_nodes.sh -db=$db"
		LN
	fi

	script_stop $ME

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
	script_stop $ME

	info "Run script :"
	info "$ME -db=$db -node=$(( node + 1 ))"
	LN
fi
