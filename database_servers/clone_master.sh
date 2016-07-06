#!/bin/sh

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

	[-skip_clone]        le clonage est déjà effectué.
	[-start_server_only] le serveur est cloné mais n'est pas démarré, utile que pour le nœud 1.
	[-skip_oracle]       la création des utilisateurs est déjà effectué.
"

info "$ME $@"

typeset		db=undef
typeset -i	node=-1

typeset		skip_clone=no
typeset		skip_oracle=no
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

		-skip_clone)
			skip_clone=yes
			shift
			;;

		-start_server_only)
			start_server_only=yes
			shift
			;;

		-skip_oracle)
			skip_oracle=yes
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

	if [ $max_nodes -eq 1 ]
	then
		[ $type_disks = FS ] && db_type=single_fs || db_type=single
	else
		db_type=rac
	fi

	chrono_start
	exec_cmd "ssh -t root@$server_name plescripts/oracle_preinstall/run_all.sh $db_type"
	LN

	info "Création des liens symboliques sur /mnt/plescripts pour oracle & grid"
	exec_cmd "ssh -t root@$server_name ln -s /mnt/plescripts /home/grid/plescripts"
	exec_cmd "ssh -t root@$server_name ln -s /mnt/plescripts /home/oracle/plescripts"
	LN

	info "Ajoute grid & oracle dans le groupe users pour pouvoir lire les montages NFS."
	exec_cmd "ssh -t root@$server_name plescripts/database_servers/add_oracle_grid_into_group_users.sh"
	chrono_stop "Oracle preinstall : "
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

	exec_cmd "$vm_scripts_path/start_vm $server"

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

	exec_cmd "ssh -t root@$server_name plescripts/gadgets/install.sh"
}

#	Permet au compte root du serveur de se connecter sur le SAN sans mot de passe.
function connections_ssh_db_server_to_san
{
	info "Ajoute le nom du serveur san dans ~/.ssh/known_hosts"
	typeset -r remote_keyscan=$(ssh-keyscan -t ecdsa $san_hostname | tail -1)
	typeset -r rks_escaped=$(escape_slash "$remote_keyscan")

	#	-c nécessaire si ~/.ssh/known_hosts n'existe pas
	exec_cmd -c "ssh -t root@$server_name \"sed -i '/${rks_escaped}/d' ~/.ssh/known_hosts 1>/dev/null\""
	exec_cmd "ssh -t root@$server_name \"echo \\\"$remote_keyscan\\\" >> ~/.ssh/known_hosts\""
	LN

	info "Création de la clef public"
	exec_cmd "ssh -t root@$server_name \"[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -N \\\"\\\" -f ~/.ssh/id_rsa\" || true"
	LN

	typeset -r public_key_file=id_rsa_${server_name}.pub
	info "Copier la clef public de $server_name vers $san_hostname"
	exec_cmd "scp root@$server_name:/root/.ssh/id_rsa.pub /tmp/$public_key_file"
	exec_cmd "scp /tmp/$public_key_file root@$san_hostname:/root/.ssh/$public_key_file"
	exec_cmd "rm /tmp/$public_key_file"
	LN

	info "Supprime la clef public de $server_name du serveur $san_hostname si elle existe."
	exec_cmd -c "ssh root@$san_hostname sed -i '/$server_name/d' /root/.ssh/authorized_keys"
	LN

	info "Ajoute la clef public dans ~/.ssh/authorized_keys"
	exec_cmd "ssh root@$san_hostname \"cat /root/.ssh/$public_key_file >> /root/.ssh/authorized_keys\""
	LN

	info "Supprime le fichier contenant la clef public de $server_name sur $san_hostname"
	exec_cmd "ssh root@$san_hostname rm /root/.ssh/$public_key_file"
	LN
}

#	Nomme l'initiator
function setup_iscsi_inititiator
{
	info "Set initiator name :"
	iscsi_initiator=$(get_initiator_for $db $node)
	exec_cmd "ssh -t root@$master_name \"echo InitiatorName=$iscsi_initiator > /etc/iscsi/initiatorname.iscsi\""
	LN
}

#	Sur le premier noeud les disques doivent être crées puis exportés.
function configure_disks_node1
{
	line_separator
	info "Setup SAN"
	chrono_start
	exec_cmd "ssh -t $san_conn plescripts/san/create_lun_for_db.sh -create_disk -db=${db} -node=$node"
	chrono_stop "Create disks : "
	LN

	test_pause "Check if the disks are created on the SAN"

	info "Register iscsi and create oracle disks..."
	chrono_start

	exec_cmd "ssh -t root@${server_name} plescripts/disk/discovery_target.sh"
	if [ "$type_disks" = FS ]
	then
		exec_cmd "ssh -t root@${server_name} plescripts/disk/create_oracle_fs_on_new_disks.sh"
	else
		exec_cmd "ssh -t root@${server_name} plescripts/disk/oracleasm_discovery_first_node.sh"
	fi
	chrono_stop "Create oracle disks : "

	line_separator
	info "Mount point for oracle installation"
	case $type_shared_fs in
		nfs)
			fstab="$client_hostname:/root/${oracle_install} /mnt/oracle_install nfs rsize=8192,wsize=8192,timeo=14,intr,noauto"
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
	info "Noeud $node disks on SAN exists"
	chrono_start
	exec_cmd "ssh -t $san_conn plescripts/san/create_lun_for_db.sh -db=${db} -node=$node"
	exec_cmd "ssh -t root@${server_name} plescripts/disk/oracleasm_discovery_other_nodes.sh"
	chrono_stop "SAN create disks : "
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

	line_separator
	connection_ssh_with_root_on_orclmaster

	line_separator
	register_server_2_dns

	line_separator
	setup_iscsi_inititiator

	line_separator
	configure_ifaces_hostname_and_reboot

	line_separator
	typeset -r local_host=$(hostname -s)
	info "Ajoute le nom de $server_name dans ~/.ssh/known_hosts $local_host"
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

[ $skip_clone == no ]	&& configure_server || true

[ $skip_oracle = no ]	&& configure_oracle_accounts || true

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
	LN

	reboot_server $server_name
	LN
fi

if [ $node -eq $max_nodes ]
then	# C'est le dernier noeud
	if [ $max_nodes -ne 1 ]
	then	# Plus de 1 noeud donc c'est un RAC.
		exec_cmd "~/plescripts/database_servers/apply_ssh_prereq_on_all_nodes.sh -db=$db"
		LN
	fi

	if [ $type_disks = FS ]
	then
		info "Oracle peut être installé."
		info "./install_oracle.sh -db=$db"
	else
		info "Le grid peut être installé."
		info "./install_grid.sh -db=$db"
	fi
	LN
elif [ $max_nodes -ne 1 ]
then	# Ce n'est pas le dernier noeud et il y a plus de 1 noeud.
	info "Exécuter le script :"
	info "$ME -db=$db -node=$(( node + 1 ))"
	LN
fi

info "Script : $( fmt_seconds $(( SECONDS - script_start_at )) )"
LN
