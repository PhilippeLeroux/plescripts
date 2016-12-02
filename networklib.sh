# vim: ts=4:sw=4

#*> Convert net prefix to net mask
#*>	$1 net prefix
#*> return net mask
function convert_net_prefix_2_net_mask
{
	typeset -i net_prefix=$1

	while [ $net_prefix -ne 0 ]
	do
		if [ $net_prefix -lt 8 ]
		then
			binary=$(fill 1 $net_prefix)
			typeset -i decimal=2#$binary
			[ x"$mask" == x ] && mask=$decimal || mask="${mask}.$decimal"
			net_prefix=0
		else
			net_prefix=net_prefix-8
			[ x"$mask" == x ] && mask=255 || mask="${mask}.255"
		fi
	done

	echo $mask
}

#*> Retourne le chemin contenant les fichiers de configuration des
#*> interfaces réseaux.
function get_if_path
{
	typeset	-r	id=$(grep "^ID=" /etc/os-release | cut -d= -f2)
	case $id in
		\"ol\")
			echo "/etc/sysconfig/network-scripts"
			;;

		opensuse|suse)
			echo "/etc/sysconfig/network"
			;;

		*)
			error "Unknow ID=$id"
			return 1
	esac
	return 0
}

#*>	Retourne l'adresse mac de l'Iface $1
function get_if_hwaddr
{
	ip link show $1 | grep link | tr -s [:space:] | cut -d' ' -f3
}

#*> Retourne 0 si l'ip $1 existe sinon 1
function dns_test_if_ip_exist
{
	ssh $dns_conn "~/plescripts/dns/test_ip_node_used.sh $1"
}

#*< Permet de nettoyer mon bordel.
function cleanup_know_host
{
	info "Cleanup ~/.ssh/known_hosts on $(hostname -s)"
	info "    -Remove all blanck lines"
	exec_cmd "sed -i -e '/^$/d' ~/.ssh/known_hosts"
}

#*> retourne l'IP de l'host $1, ou rien si l'IP n'est pas trouvée.
function get_ip_for_host
{
	typeset -r host=$1

	typeset -r output=$(nslookup $host)

	if grep -q "server can't find "<<<"$output"
	then
		return 1
	fi

	if [ $? -eq 0 ]
	then
		echo "$output" | grep -E ^Address | tail -1 | cut -d' ' -f2
		return 0
	else
		return 1
	fi
}

#*> Supprime l'ip $1 du fichier ~/.ssh/know_hosts
function remove_ip_from_known_hosts
{
	typeset -r ip=$1

	[ ! -f ~/.ssh/known_hosts ] && return 0

	info "Remove $ip from ~/.ssh/known_hosts"
	exec_cmd "sed -i /^$ip/d" ~/.ssh/known_hosts
	LN
}

#*> Supprime du fichier ~/.ssh/know_host l'hôte $1
function remove_from_known_hosts
{
	typeset -r host=$1

	[ ! -f ~/.ssh/known_hosts ] && return 0

	info "Remove $host from ~/.ssh/known_hosts"
	exec_cmd "sed -i /^$host/d" ~/.ssh/known_hosts
	LN

	typeset -r ip=$(get_ip_for_host $host)
	if [ x"$ip" != x ]
	then # Normallement on ne doit plus trouver d'IP seul, mais au cas ou...
		remove_ip_from_known_hosts $ip
	fi
}

#*>	$1 server name.
#*>	return public key for server $1
function get_public_key_for
{
	typeset -r srv_name=$1
	typeset -r server_ip=$(get_ip_for_host $srv_name)

	ssh-keyscan -t ecdsa $srv_name | tail -1 | sed "s/$srv_name/$srv_name,$server_ip/"
}

#*> Ajoute le serveur $1 au fichier ~/.ssh/known_hosts
function add_to_known_hosts
{
	typeset -r srv_name=$1

	info "Add to $HOME/.ssh/know_hosts server : $srv_name"
	LN

	exec_cmd -c "sed -i '/^$srv_name.*/d' ~/.ssh/known_hosts 1>/dev/null"
	LN

	typeset -r server_keyscan=$(get_public_key_for $srv_name)
	if [ x"$server_keyscan" == x ]
	then
		error "Can't obtain public key for $srv_name"
		exit 1
	fi
	exec_cmd "echo \"$server_keyscan\" >> ~/.ssh/known_hosts"
	LN
}
