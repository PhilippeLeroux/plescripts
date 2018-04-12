#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset		fake=no

typeset	-r	str_usage="Usage : $ME [-fake]"

while [ $# -ne 0 ]
do
	case $1 in
		-fake)
			fake=yes
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done


function replace
{
	typeset	-r	str1=$(escape_slash $1)
	typeset	-r	str2=$(escape_slash $2)
	typeset	-r	file=$3

	exec_cmd "sed -i \"s/\<$str1\>/$str2/g\" $file"
}

function copy
{
	exec_cmd "cp $1 $2"
	[ $fake == yes ] && return 0 || true

	exec_cmd "chown root.named $2"
	exec_cmd "chmod u=rw,g=rw,o=r $2"
}

case $fake in
	yes)
		etc_path=etc
		var_named_path=var/named
		[ ! -d $etc_path ] && exec_cmd mkdir $etc_path || true
		[ ! -d $var_named_path ] && exec_cmd mkdir -p $var_named_path || true
		;;

	no)
		etc_path=/etc
		var_named_path=/var/named
		;;
esac

IFS='.' read ip1 ip2 ip3 rem<<<"$dns_ip"
typeset	-r	reversed_network="$ip3.$ip2.$ip1"

typeset	-r	dhcpd_conf_template=~/plescripts/dns/install/config_template/dhcpd.conf.template

typeset	-r	named_conf_template=~/plescripts/dns/install/config_template/named.conf.template
typeset	-r	name_domain_template=~/plescripts/dns/install/config_template/named.domain.template
typeset	-r	reverse_domain_template=~/plescripts/dns/install/config_template/reverse.domain.template

typeset	-r	dhcpd_conf=$etc_path/dhcp/dhcpd.conf
typeset	-r	named_conf=$etc_path/named.conf
typeset	-r	named_domain=$var_named_path/named.${infra_domain}
typeset	-r	reverse_domain=$var_named_path/reverse.${infra_domain}

info "Generate dnssec key"
OPWD=$PWD
fake_exec_cmd cd $HOME
cd $HOME
info "Remove olds .key & .private"
exec_cmd "rm -f *.key *.private"
LN
typeset	-r	dnssec_prefix=$(dnssec-keygen -a hmac-md5 -b 128 -n USER dhcpupdate)
typeset	-r	dnssec_key="$(cat ${dnssec_prefix}.key | awk '{ print $7 }')"
exec_cmd "ls -1l ${dnssec_prefix}*"
info "dnssec key : '$dnssec_key'"
LN
fake_exec_cmd cd $OPWD
cd $OPWD

line_separator
info "DHCP :"
info "	server   $infra_hostname"
info "	ip       $dns_ip"
info "	domain   $infra_domain"
info "	reversed $reversed_network"
LN

IFS='.' read ip1 ip2 ip3 rem<<<"$if_iscsi_network"
typeset	-r	reversed_iscsi_network="$ip3.$ip2.$ip1"
typeset	-r	iscsi_network_mask=$(convert_net_prefix_2_net_mask $if_iscsi_prefix)

IFS='.' read ip1 ip2 ip3 rem<<<"$gateway"
typeset	-r	net_network=$(cut -d. -f1-3<<<"$gateway")
typeset	-r	net_network_mask=255.255.255.0

typeset	-r	pub_network_mask=$(convert_net_prefix_2_net_mask $if_pub_prefix)

case $if_pub_prefix in
	8)
		typeset	-r	infra_broadcast=$(cut -d. -f1<<<"$infra_ip").255.255.255
		;;
	16)
		typeset	-r	infra_broadcast=$(cut -d. -f1-2<<<"$infra_ip").255.255
		;;
	24)
		typeset	-r	infra_broadcast=$(cut -d. -f1-3<<<"$infra_ip").255
		;;
esac

info "Configuration de $dhcpd_conf :"
copy $dhcpd_conf_template $dhcpd_conf
replace	DOMAIN_NAME				$infra_domain						$dhcpd_conf
replace	MY_NETWORK				$infra_network.0					$dhcpd_conf
replace	MY_NETWORK_MASK			$pub_network_mask					$dhcpd_conf
replace	INFRA_HOSTNAME			$infra_hostname						$dhcpd_conf
replace	INFRA_IP				$infra_ip							$dhcpd_conf
replace	DOMAIN_NAME				$infra_domain						$dhcpd_conf
replace	ISCSI_NETWORK			$if_iscsi_network.0					$dhcpd_conf
replace	ISCSI_NETWORK_MASK		$iscsi_network_mask					$dhcpd_conf
replace	NET_NETWORK				$net_network.0						$dhcpd_conf
replace	REVERSED_NETWORK		$reversed_network					$dhcpd_conf
replace	NET_NETWORK_MASK		$net_network_mask					$dhcpd_conf
replace	DNSSEC_SECRET			$dnssec_key							$dhcpd_conf
replace	INFRA_IP_BROADCAST		$infra_broadcast					$dhcpd_conf
replace	DHCP_MIN_IP				$infra_network.$dhcp_min_ip_node	$dhcpd_conf
replace	DHCP_MAX_IP				$infra_network.$dhcp_max_ip_node	$dhcpd_conf
LN

line_separator
info "DNS :"
info "	server   $infra_hostname"
info "	ip       $dns_ip"
info "	domain   $infra_domain"
info "	reversed $reversed_network"
LN

IFS='.' read ip1 ip2 ip3 ip4 rem<<<"$infra_ip"
typeset	-r	reversed_infra_ip="$ip4.$ip3.$ip2.$ip1"

info "Configuration de $named_conf :"
copy $named_conf_template $named_conf
replace	DNS_IP				$dns_ip				$named_conf
replace	DOMAIN_NAME			$infra_domain		$named_conf
replace	REVERSED_NETWORK	$reversed_network	$named_conf
replace	MY_NETWORK			$infra_network.0	$named_conf
replace	MY_NETWORK_PREFIX	$if_pub_prefix		$named_conf
replace	INFRA_IP_REVERSED	$reversed_infra_ip	$named_conf
replace	DNSSEC_SECRET		$dnssec_key			$named_conf
LN

info "Configuration de $named_domain"
copy $name_domain_template $named_domain
replace	DNS_NAME	$infra_hostname	$named_domain
replace	DNS_IP		$dns_ip			$named_domain
LN

info "Configuration de $reverse_domain"
copy $reverse_domain_template $reverse_domain
replace	DNS_NAME			$infra_hostname		$reverse_domain
replace	DOMAIN_NAME			$infra_domain		$reverse_domain
replace	REVERSED_NETWORK	$reversed_network	$reverse_domain
replace	DNS_IP_NODE			$dns_ip_node		$reverse_domain
LN

[ $fake == yes ] && exit 0 || true

info "Stop IPV6 errors"
exec_cmd "sed -i '6i OPTIONS="-4"' /etc/sysconfig/named"
LN

line_separator
info "named can create file in /var/named."
exec_cmd "chmod g=rwx /var/named"
LN

line_separator
info "Setup DHCP"
exec_cmd "touch /var/lib/dhcpd/dhcpd.leases"
LN

line_separator
info "Setup selinux"
exec_cmd "chcon -R -t named_zone_t '/var/named/'"
exec_cmd "chcon -R -t dnssec_trigger_var_run_t '/var/named/'"
LN

info "Setup dhcpd to listen on $if_pub_name"
exec_cmd "cp /usr/lib/systemd/system/dhcpd.service /etc/systemd/system/"
exec_cmd "sed -i 's/--no-pid/--no-pid $if_pub_name/' /etc/systemd/system/dhcpd.service"
LN

line_separator
info "Enable and start named."
exec_cmd systemctl enable named
exec_cmd systemctl start named
LN

info "Enable and start dhcpd."
exec_cmd systemctl enable dhcpd
exec_cmd systemctl start dhcpd
LN
