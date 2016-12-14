#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -role=[infra|master]
Configure NTP for infra or master server.
"

typeset role=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-role=*)
			role=${1##*=}
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

exit_if_param_invalid role "master infra" "$str_usage"

typeset -r ntp_conf=/etc/ntp.conf
typeset	-r sysconfig_ntpd=/etc/sysconfig/ntpd

exit_if_file_not_exists $ntp_conf

[ $role == master ] && time_server=$infra_hostname || time_server=$master_time_server

function configure_ntp
{
	info "Config $ntp_conf"
	exec_cmd "cp $ntp_conf ${ntp_conf}.backup"
	LN

	exec_cmd "sed -i '/^server.*iburst$/d' $ntp_conf"
	LN

	typeset	-r s1="# Hosts on local network are less restricted."
	typeset	-r mask=$(convert_net_prefix_2_net_mask $if_pub_prefix)
	typeset	-r network=$(right_pad_ip $infra_network)
	exec_cmd "sed -i '/$s1/a restrict $network mask ${mask} nomodify notrap' $ntp_conf"
	LN

	typeset	-r s2=$(escape_slash "# Please consider joining the pool (http://www.pool.ntp.org/join.html).")
	#	Sur un réseau local utiliser burst (iburst c'est pour internet)
	exec_cmd "sed -i '/$s2/a server $time_server burst' $ntp_conf"
	LN

	info "Config $sysconfig_ntpd"
	exec_cmd "sed -i 's,^OPTIONS.*,OPTIONS=\"-x -u ntp:ntp -p /var/run/ntpd.pid\",' $sysconfig_ntpd"
	exec_cmd "echo 'SYNC_HWCLOCK=yes' >> $sysconfig_ntpd"
	LN
}

function configure_ntpdate
{
	typeset -r ntpdate_conf=/etc/ntp/step-tickers
	typeset	-r sysconfig_ntpdate=/etc/sysconfig/ntpdate

	exec_cmd "echo '$infra_hostname' > $ntpdate_conf"
	LN

	exec_cmd "sed -i 's/SYNC_HWCLOCK=.*/SYNC_HWCLOCK=yes/' $sysconfig_ntpdate"
	LN

	info "Sync $(hostname -s) with $infra_hostname"
	exec_cmd "ntpdate $infra_hostname"
	LN

	exec_cmd "systemctl enable ntpdate"
	exec_cmd "systemctl start ntpdate"
	LN
}

[ $time_server != internet ] && configure_ntp || true

if [ $role == infra ]
then
	[ ! -f ${ntp_conf}.backup ] && exec_cmd "cp $ntp_conf ${ntp_conf}.backup"

	typeset	-r network=$(right_pad_ip $infra_network)
	exec_cmd "sed -i 's/.*allow .*/allow ${network}\/$if_pub_prefix/g' $ntp_conf"
	LN

	exec_cmd "systemctl enable ntpdate"
	exec_cmd "systemctl start ntpdate"
	LN

	exec_cmd "ntpdate $infra_hostname"
	LN
fi

[ $role == master ] && configure_ntpdate || true

info "Enabled & start ntpd"
exec_cmd "systemctl enable ntpd"
exec_cmd "systemctl start ntpd"
LN

exec_cmd "ntpq -p"
LN
