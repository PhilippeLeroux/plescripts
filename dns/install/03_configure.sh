#!/bin/bash

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

typeset -r ME=$0
typeset -r str_usage="Usage : $ME [-emul]"

typeset action=real
EXEC_CMD_ACTION=EXEC

PLELIB_OUTPUT=FILE
PLELIB_LOG_FILE=configure.log

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			action=emul
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

case $action in
	emul)
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

typeset -r hostn=$(hostname -s)
typeset -r domain_name=$(hostname -d)

IFS='.' read ip1 ip2 ip3 rem<<<"$dns_ip"
typeset -r reversed_network="$ip3.$ip2.$ip1"

typeset -r named_conf_template=~/plescripts/dns/install/config_template/named.conf.template
typeset -r name_domain_template=~/plescripts/dns/install/config_template/named.domain.template
typeset -r reverse_domain_template=~/plescripts/dns/install/config_template/reverse.domain.template

typeset -r named_conf=$etc_path/named.conf
typeset -r named_domain=$var_named_path/named.${domain_name}
typeset -r reverse_domain=$var_named_path/reverse.${domain_name}

info "DNS :"
info "	server   $hostn"
info "	ip       $dns_ip"
info "	domain   $domain_name"
info "	reversed $reversed_network"
LN

[ x"$domain_name" = x ] && error "Vérifier la configuration de /etc/hostname" && exit 1

info "Configuration de $named_conf :"
copy $named_conf_template $named_conf
replace DNS_IP				$dns_ip				$named_conf
replace DOMAIN_NAME			$domain_name		$named_conf
replace	REVERSED_NETWORK	$reversed_network	$named_conf
replace MY_NETWORK			$infra_network		$named_conf
replace MY_MASK				$infra_mask			$named_conf
LN

info "Configuration de $named_domain"
copy $name_domain_template $named_domain
replace DNS_NAME	$hostn	$named_domain
replace DNS_IP		$dns_ip	$named_domain
LN

info "Configuration de $reverse_domain"
copy $reverse_domain_template $reverse_domain
replace DNS_NAME			$hostn				$reverse_domain
replace DOMAIN_NAME			$domain_name		$reverse_domain
replace REVERSED_NETWORK	$reversed_network	$reverse_domain
replace DNS_IP_NODE			$dns_ip_node		$reverse_domain
LN

exec_cmd -c systemctl enable named
exec_cmd -c systemctl restart named
