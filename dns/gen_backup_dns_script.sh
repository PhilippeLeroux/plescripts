#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

#	============================================================
#	Le script par du princide que le réseau est toujours en 24 !
#	============================================================

pub_network_prefix=$(ip addr	| grep $if_pub_name | grep inet | cut -d/ -f2 \
								| sed "s/^\([0-9]\{1,2\}\) brd.*/\1/")

if [ "$pub_network_prefix" != 24 ]
then
	error "Fonctionne avec un préfixe réseau de 24 mais pas de $pub_network_prefix"
	LN
	exit 1
fi

echo "#!/bin/bash" > ~/plescripts/tmp/restore_dns.sh
echo "cd ~/plescripts/dns" >> ~/plescripts/tmp/restore_dns.sh
echo >> ~/plescripts/tmp/restore_dns.sh

echo "systemctl stop dhcpd"  >> ~/plescripts/tmp/restore_dns.sh
echo "systemctl stop named"  >> ~/plescripts/tmp/restore_dns.sh
echo >> ~/plescripts/tmp/restore_dns.sh

typeset -r	domain=$(hostname -d)

#	Trié par rapport à l'ip node.
cat /var/named/named.$domain	|\
	grep "^[[:alpha:]].*"		|\
	grep -v localhost			|\
	sort -n -t "." -k 4			|\
while read server_name f1 server_ip
do
	ip_node=$(cut -d. -f4<<<"$server_ip")
	if [[ $ip_node -ge $dhcp_min_ip_node && $ip_node -le $dhcp_max_ip_node ]]
	then # Les IP dynamiques ne sont pas sauvées.
		continue
	else
		echo "./add_server_2_dns.sh -name=$server_name -ip=$server_ip -not_restart_named"
		if [ "${server_name##*-}" == "scan" ]
		then # Cas particulier des adresses de SCANs.
			network_scan=$(cut -d. -f1-3<<<"$server_ip")
			for (( i=1; i <= 2; ++i ))
			do
				echo "./add_server_2_dns.sh -name=$server_name -ip=$network_scan.$(( ip_node + i )) -not_restart_named"
			done
		fi
	fi
done >> ~/plescripts/tmp/restore_dns.sh

typeset	-r	leases_file="/var/lib/dhcpd/dhcpd.leases"
echo >> ~/plescripts/tmp/restore_dns.sh
echo "rm $leases_file"  >> ~/plescripts/tmp/restore_dns.sh
echo "touch $leases_file"  >> ~/plescripts/tmp/restore_dns.sh
echo >> ~/plescripts/tmp/restore_dns.sh

echo "systemctl start named"  >> ~/plescripts/tmp/restore_dns.sh
echo "systemctl start dhcpd"  >> ~/plescripts/tmp/restore_dns.sh
echo >> ~/plescripts/tmp/restore_dns.sh

chmod ug+x ~/plescripts/tmp/restore_dns.sh

info "Script : ~/plescripts/tmp/restore_dns.sh"
exec_cmd "cat ~/plescripts/tmp/restore_dns.sh"
