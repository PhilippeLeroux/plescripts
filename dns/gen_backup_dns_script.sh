#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

echo "#!/bin/bash" > ~/plescripts/tmp/restore_dns.sh
echo "cd ~/plescripts/dns" >> ~/plescripts/tmp/restore_dns.sh

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
	fi
done >> ~/plescripts/tmp/restore_dns.sh

echo "systemctl restart named.service" >> ~/plescripts/tmp/restore_dns.sh

chmod ug+x ~/plescripts/tmp/restore_dns.sh

info "Script : ~/plescripts/tmp/restore_dns.sh"
exec_cmd "cat ~/plescripts/tmp/restore_dns.sh"
