#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
Configure NTP for RAC server.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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
			exit 1
			;;
	esac
done

typeset -r time_server=$infra_hostname

typeset -r ntp_conf=/etc/ntp.conf

function install_ntp
{
	info "Uninstall chrony."
	exec_cmd "LANG=C yum -y erase chrony"
	LN

	info "Install ntp."
	exec_cmd "LANG=C yum -y install ntp"
	LN
}

function configure_and_start_ntpdate
{
	typeset -r ntpdate_conf=/etc/ntp/step-tickers

	exec_cmd "echo '$infra_hostname' > $ntpdate_conf"
	LN

	info "Sync $(hostname -s) with $infra_hostname"
	exec_cmd "ntpdate $infra_hostname"
	exec_cmd "ntpdate $infra_hostname"
	LN

	exec_cmd "systemctl enable ntpdate"
	exec_cmd "systemctl start ntpdate"
	LN
}

function configure_ntp
{
	typeset	-r sysconfig_ntpd=/etc/sysconfig/ntpd

	info "Config $ntp_conf"
	exec_cmd "cp $ntp_conf ${ntp_conf}.backup"
	LN

	if [ $rac_ntp_tinker_panic == yes ]
	then
		exec_cmd "sed -i '4itinker panic 0' $ntp_conf"
		LN
	fi

	exec_cmd "sed -i '/^server.*iburst$/d' $ntp_conf"
	LN

	typeset	-r s1="# Hosts on local network are less restricted."
	typeset	-r mask=$(convert_net_prefix_2_net_mask $if_pub_prefix)
	typeset	-r network=$(right_pad_ip $infra_network)
	exec_cmd "sed -i '/$s1/a restrict $network mask ${mask} nomodify notrap' $ntp_conf"
	LN

	typeset	-r s2=$(escape_slash "# Please consider joining the pool (http://www.pool.ntp.org/join.html).")
	#	'burst' est conseillé sur un réseau local.
	exec_cmd "sed -i '/$s2/a server $time_server burst' $ntp_conf"
	LN

	info "Config $sysconfig_ntpd"
	exec_cmd "sed -i 's,^OPTIONS.*,OPTIONS=\"-x -g -I $if_pub_name -p /var/run/ntpd.pid\",' $sysconfig_ntpd"
	LN
}

[ ! -f $ntp_conf ] && install_ntp || true

configure_ntp
configure_and_start_ntpdate

info "Enabled & start ntpd"
exec_cmd "systemctl enable ntpd"
LN
exec_cmd "systemctl start ntpd"
LN
exec_cmd "ntpq -p"
LN
