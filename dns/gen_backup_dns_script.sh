#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

echo "#!/bin/bash" > ~/plescripts/tmp/restore_dns.sh
echo "cd ~/plescripts/dns" >> ~/plescripts/tmp/restore_dns.sh

typeset -r	domain=$(hostname -d)

#	Trié par rapport à l'ip node.
cat /var/named/named.$domain	|\
	grep "^[[:alpha:]].*"		|\
	grep -v localhost			|\
	sort -n -t "." -k 4			|\
while read server_name f2 f3 server_ip
do
	echo "./add_server_2_dns.sh -name=$server_name -ip=$server_ip -not_restart_named"
done >> ~/plescripts/tmp/restore_dns.sh
echo "systemctl restart named.service" >> ~/plescripts/tmp/restore_dns.sh
chmod ug+x ~/plescripts/tmp/restore_dns.sh

info "Script : ~/plescripts/tmp/restore_dns.sh"
exec_cmd "cat ~/plescripts/tmp/restore_dns.sh"
