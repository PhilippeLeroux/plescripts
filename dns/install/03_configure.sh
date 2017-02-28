#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME [-emul]"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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
	typeset -r str1=$1
	typeset -r str2=$2
	typeset -r file=$3

	exec_cmd "sed -i \"s/\<$str1\>/$str2/g\" $file"
}

function copy
{
	exec_cmd "cp $1 $2"
	exec_cmd -c "chown root.named $2"
	exec_cmd "chmod u=rw,g=rw,o=r $2"
}

case $EXEC_CMD_ACTION in
	NOP)
		etc_path=etc
		var_named_path=var/named
		[ ! -d $etc_path ] && exec_cmd mkdir $etc_path
		[ ! -d $var_named_path ] && exec_cmd mkdir -p $var_named_path
		;;

	*)
		etc_path=/etc
		var_named_path=/var/named
		;;
esac

IFS='.' read ip1 ip2 ip3 rem<<<"$dns_ip"
typeset -r reversed_network="$ip3.$ip2.$ip1"

typeset -r named_conf_template=~/plescripts/dns/install/config_template/named.conf.template
typeset -r name_domain_template=~/plescripts/dns/install/config_template/named.domain.template
typeset -r reverse_domain_template=~/plescripts/dns/install/config_template/reverse.domain.template

typeset -r named_conf=$etc_path/named.conf
typeset -r named_domain=$var_named_path/named.${infra_domain}
typeset -r reverse_domain=$var_named_path/reverse.${infra_domain}

info "DNS :"
info "	server   $infra_hostname"
info "	ip       $dns_ip"
info "	domain   $infra_domain"
info "	reversed $reversed_network"
LN

info "Configuration de $named_conf :"
copy $named_conf_template $named_conf
replace DNS_IP				$dns_ip				$named_conf
replace DOMAIN_NAME			$infra_domain		$named_conf
replace	REVERSED_NETWORK	$reversed_network	$named_conf
replace MY_NETWORK			$infra_network		$named_conf
replace MY_MASK				$if_pub_prefix		$named_conf
LN

info "Configuration de $named_domain"
copy $name_domain_template $named_domain
replace DNS_NAME	$infra_hostname	$named_domain
replace DNS_IP		$dns_ip			$named_domain
LN

info "Configuration de $reverse_domain"
copy $reverse_domain_template $reverse_domain
replace DNS_NAME			$infra_hostname		$reverse_domain
replace DOMAIN_NAME			$infra_domain		$reverse_domain
replace REVERSED_NETWORK	$reversed_network	$reverse_domain
replace DNS_IP_NODE			$dns_ip_node		$reverse_domain
LN

info "Stop IPV6 errors"
exec_cmd "sed -i '6i OPTIONS="-4"' /etc/sysconfig/named"
LN

exec_cmd -c systemctl enable named
exec_cmd -c systemctl restart named
