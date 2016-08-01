#!/bin/bash

#	ts=4 sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
EXEC_CMD_ACTION=EXEC

. ~/plescripts/global.cfg

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-db=<str>            identifiant de la base
	[-node=<#>]          n° du nœud si base de type RAC

	[-start_server_only] le serveur est cloné mais n'est pas démarré, utile que pour le nœud 1.
"

info "$ME $@"

typeset		db=undef
typeset -i	node=-1

typeset		start_server_only=no

while [ $# -ne 0 ]
do
	case $1 in
		-db=*)
			db=${1##*=}
			shift
			;;

		-node=*)
			node=${1##*=}
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

typeset -r cfg_path=~/plescripts/database_servers/$db
if [ ! -d $cfg_path ]
then
	error "$cfg_path not exits !"
	info "First run ~/plescripts/database_servers/define_new_server.sh"
	exit 1
fi

typeset -ri max_nodes=$(ls -1 $cfg_path/node*|wc -l)
[ $node = -1 ] && [ $max_nodes -eq 1 ] && node=1

exit_if_param_undef node	"$str_usage"

typeset -r cfg_file=$cfg_path/node$node
exit_if_file_not_exists $cfg_file "$str_usage"

typeset -r server_name=$(cat $cfg_file | cut -d: -f2)

typeset -r type_disks=$(cat ~/plescripts/database_servers/$db/disks | tail -1 | cut -d: -f1)

typeset -r vg_name=asm01

#	Équivalence ssh entre le poste client et root@orclmaster
function connection_ssh_with_root_on_orclmaster
{
	exec_cmd "~/plescripts/shell/connections_ssh_with.sh -server=$master_name -user=root"
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
		[ $type_disks == FS ] && db_type=single_fs || db_type=single
	fi

	exec_cmd "ssh -t root@$server_name plescripts/oracle_preinstall/run_all.sh $db_type"
	LN

	line_separator
	info "Create link for root user."
	exec_cmd "ssh -t root@$server_name 'ln -s ~/plescripts/disk ~/disk'"
	exec_cmd "ssh -t root@$server_name 'ln -s ~/plescripts/yum ~/yum'"
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

	line_separator
	info "Reboot :"
	exec_cmd "$vm_scripts_path/stop_vm $server"
	info -n "Wait : "; pause_in_secs 20; LN
	LN

	while [ 0 -eq 0 ]	# forever
	do
		exec_cmd -c "$vm_scripts_path/start_vm $server"
		[ $? -eq 0 ] && break

		LN
		confirm_or_exit "Start failed, try again"
	done

	loop_wait_server $server
}

function configure_ifaces_hostname_and_reboot
{
	info "Configure network..."
	exec_cmd "ssh -t $master_conn plescripts/configure_network/setup_iface_and_hostename.sh -db=$db -node=$node; exit"
	LN

	reboot_server $server_name

	test_pause "$server_name : Check network configuration."
}

#	Connexion ssh sans mot de passe entre le poste client et :
#		root@$server_name
#		grid@$server_name
#		oracle@$server_name
function connections_ssh_client_to_db_server
{
	exec_cmd "~/plescripts/ssh/db_connections_ssh_to_server.sh -remote_server=$server_name"
	LN

	test_pause "$server_name : Check connections."
}

#	Permet au compte root du serveur de se connecter sur le SAN sans mot de passe.
function connections_ssh_db_server_to_san
{
	info "Add san server to file ~/.ssh/known_hosts"
	typeset -r remote_keyscan=$(ssh-keyscan -t ecdsa $san_hostname | tail -1)
	typeset -r rks_escaped=$(escape_slash "$remote_keyscan")

	#	-c nécessaire si ~/.ssh/known_hosts n'existe pas
	exec_cmd -c "ssh -t root@$server_name \"sed -i '/${rks_escaped}/d' ~/.ssh/known_hosts 1>/dev/null\""
	exec_cmd "ssh -t root@$server_name \"echo \\\"$remote_keyscan\\\" >> ~/.ssh/known_hosts\""
	LN

	info "Create public key."
	exec_cmd "ssh -t root@$server_name \"[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -N \\\"\\\" -f ~/.ssh/id_rsa\" || true"
	LN

	typeset -r public_key_file=id_rsa_${server_name}.pub
	info "Copy public key from $server_name to $san_hostname"
	exec_cmd "scp root@$server_name:/root/.ssh/id_rsa.pub /tmp/$public_key_file"
	exec_cmd "scp /tmp/$public_key_file root@$san_hostname:/root/.ssh/$public_key_file"
	exec_cmd "rm /tmp/$public_key_file"
	LN

	info "Remove public key $server_name from $san_hostname."
	exec_cmd -c "ssh root@$san_hostname sed -i '/$server_name/d' /root/.ssh/authorized_keys"
	LN

	info "Add public key to ~/.ssh/authorized_keys"
	exec_cmd "ssh root@$san_hostname \"cat /root/.ssh/$public_key_file >> /root/.ssh/authorized_keys\""
	LN

	info "Remove public key file for $server_name from $san_hostname"
	exec_cmd "ssh root@$san_hostname rm /root/.ssh/$public_key_file"
	LN
}

#	Nomme l'initiator
function setup_iscsi_inititiator
{
	info "Setup initiator name :"
	iscsi_initiator=$(get_initiator_for $db $node)
	exec_cmd "ssh -t root@$master_name \"echo InitiatorName=$iscsi_initiator > /etc/iscsi/initiatorname.iscsi\""
	LN
}

#	Sur le premier noeud les disques doivent être crées puis exportés.
function configure_disks_node1
{
	line_separator
	info "Setup SAN"
	exec_cmd "ssh -t $san_conn plescripts/san/create_lun_for_db.sh -create_lv -vg_name=$vg_name -db=${db} -node=$node"
	LN

	test_pause "Check if the disks are created on the SAN"

	line_separator
	info "Register iscsi and create oracle disks..."
	typeset TD=ASM
	[ $type_disks == FS ] && TD=FS
	exec_cmd "ssh -t root@${server_name} plescripts/disk/oracleasm_discovery_first_node.sh -type_disk=$TD"
	LN

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

#	Dans le cas d'un RAC les autres noeuds vont se connecter au portail et
#	appeler oracleasm pour accéder aux disques.
function configure_disks_other_node_than_1
{
	line_separator
	info "Node $node disks on SAN exists"
	exec_cmd "ssh -t $san_conn plescripts/san/create_lun_for_db.sh -vg_name=$vg_name -db=${db} -node=$node"
	exec_cmd "ssh -t root@${server_name} plescripts/disk/oracleasm_discovery_other_nodes.sh"
	LN
}

#	Attend que le serveur master soit actif.
function wait_master
{
	~/plescripts/shell/wait_server $master_name
	[ $? -ne 0 ] && exit 1
	LN

if [ 0 -eq 1 ]; then # Désactivé, plus besoins de saisir le mot de passe.
	chrono_start
	info "You are ready : press a key."
	read keyboard
	LN
	chrono_stop "Wait user : "
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
		exec_cmd "$vm_scripts_path/clone_vm.sh -db=$db -vm_memory_mb=$vm_memory"
	fi

	exec_cmd "$vm_scripts_path/start_vm $server_name"
	wait_master

	#	La VM ayant été clonée elle a la configuration réseau du master.
	#	Donc son nom est $master_name
	line_separator
	test_if_rpm_update_available $master_name
	[ $? -eq 0 ] && exec_cmd "ssh -t root@$master_name \"yum -y update\""
	LN

	#N'est plus utile, la clef est créée sur le master.
	#line_separator
	#connection_ssh_with_root_on_orclmaster

	line_separator
	register_server_2_dns

	line_separator
	setup_iscsi_inititiator

	line_separator
	configure_ifaces_hostname_and_reboot

	#	Maintenant le serveur a son nom définitif : $server_name.

	line_separator
	typeset -r local_host=$(hostname -s)
	info "Add name '$server_name' to ~/.ssh/known_hosts de $local_host"
	typeset -r remote_keyscan=$(ssh-keyscan -t ecdsa $server_name | tail -1)
	typeset -r rks_escaped=$(escape_slash "$remote_keyscan")
	exec_cmd -c "sed -i '/${rks_escaped}/d' ~/.ssh/known_hosts 1>/dev/null"
	exec_cmd "echo \"$remote_keyscan\" >> ~/.ssh/known_hosts"
	LN

	line_separator
	connections_ssh_db_server_to_san
	LN
}

#	Met en place tous les pré requis Oracle
function configure_oracle_accounts
{
	run_oracle_preinstall

	connections_ssh_client_to_db_server

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
typeset -r script_start_at=$SECONDS

[ $node -gt 1 ]			&& test_if_other_nodes_up || true

configure_server

configure_oracle_accounts

copy_color_file

if [ $node -eq 1 ]
then
	configure_disks_node1
else
	configure_disks_other_node_than_1
fi

info "Plymouth theme"
exec_cmd -c "ssh -t root@$server_name plescripts/shell/set_plymouth_them"
LN

reboot_server $server_name
LN

if [ $type_shared_fs == vbox ]
then
	exec_cmd "$vm_scripts_path/compile_guest_additions.sh -host=$server_name"
fi

if [ $node -eq $max_nodes ]
then	# C'est le dernier noeud
	if [ $max_nodes -ne 1 ]
	then	# Plus de 1 noeud donc c'est un RAC.
		exec_cmd "~/plescripts/database_servers/apply_ssh_prereq_on_all_nodes.sh -db=$db"
		LN
	fi

	if [ $type_disks == FS ]
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
	info "Run script :"
	info "$ME -db=$db -node=$(( node + 1 ))"
	LN
fi

info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
LN
