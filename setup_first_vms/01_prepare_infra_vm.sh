#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

info "Update /etc/hostname with ${infra_hostname}.${infra_domain}"
exec_cmd "echo \"${infra_hostname}.${infra_domain}\" > /etc/hostname"
LN

line_separator
info "Update Iface $if_pub_name"
if_hwaddr=$(get_if_hwaddr $if_pub_name)
exec_cmd nmcli connection modify	$if_pub_name					\
									ethernet.mac-address $if_hwaddr
LN
update_value UUID	$(uuidgen $if_pub_name)	$if_pub_file
LN

line_separator
info "Update iSCSI Iface $if_iscsi_name :"
if_hwaddr=$(get_if_hwaddr $if_iscsi_name)
if_ip=${if_iscsi_network}.${infra_ip_node}
exec_cmd nmcli connection modify			$if_iscsi_name			\
					ipv4.method				manual					\
					ipv4.addresses			$if_ip/$if_iscsi_prefix	\
					ethernet.mtu			9000					\
					connection.zone			trusted					\
					ethernet.mac-address	$if_hwaddr				\
					connection.autoconnect	yes
LN
update_value UUID	$(uuidgen $if_iscsi_name)	$if_iscsi_file
LN
exec_cmd ifup $if_iscsi_name
LN

line_separator
info "Add internet Iface $if_net_name :"
if_hwaddr=$(get_if_hwaddr $if_net_name)
exec_cmd nmcli connection add								\
					con-name				$if_net_name	\
					ifname					$if_net_name	\
					type					ethernet
LN

# ipv4.ignore-auto-dns yes correspond à PEERDNS=NO : ne pas placer l'IP dans /etc/resolv.conf
# ipv4.method auto correspond à BOOTPROTP=dhcp
exec_cmd nmcli connection modify			$if_net_name	\
					ipv4.dns				$dns_ip			\
					+ipv4.dns				$dns_main		\
					ipv4.method				auto			\
					ipv4.ignore-auto-dns	yes				\
					ipv4.dhcp-hostname		$infra_hostname	\
					connection.zone			public			\
					ethernet.mac-address	$if_hwaddr		\
					connection.autoconnect	yes
LN
update_value UUID	$(uuidgen $if_net_name)	$if_net_file
LN
exec_cmd ifup $if_net_name
LN

line_separator
info "Create links on frequently used directories"
exec_cmd "ln -s ~/plescripts/san ~/san"
exec_cmd "ln -s ~/plescripts/dns ~/dns"
LN
