
#	ts=4 sw=4

#*> Retourne le chemin contenant les fichiers de configuration des
#*> interfaces réseaux.
function get_if_path
{
	id=$(grep "^ID=" /etc/os-release | cut -d= -f2)
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
	if [ $? -eq 0 ]
	then
		echo $ouput | grep ^Address | tail -1 | cut -d' ' -f2
	fi
}

#*> Supprime du fichier ~/.ssh/know_host l'hôte $1
function remove_from_known_hosts
{
	typeset -r host=$1
	info "Remove $host from ~/.ssh/known_hosts"
	exec_cmd "sed -i /^$host/d" ~/.ssh/known_hosts
	LN

	typeset -r ip=$(get_ip_for_host $host)
	if [ x"$ip" != x ]
	then
		info "Remove $ip from ~/.ssh/known_hosts"
		exec_cmd "sed -i /^$ip/d" ~/.ssh/known_hosts
		LN
	fi

	exec_cmd sed -i '/^$/d' ~/.ssh/known_hosts
}
