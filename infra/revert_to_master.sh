#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=NOP

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-doit]
	Le GI et le logiciel Oracle doivent avoir été désinstallés.

	- Supprime les comptes oracle & grid.
	- Renomme le serveur en $master_name
	- Positionne l'IP ${if_pub_network}.${master_ip_node} sur $if_pub_name
	- Supprime de /etc/fstab : /mnt/oracle_install
"

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-doit)
			EXEC_CMD_ACTION=EXEC
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

[ $USER != root ] && error "Only root !" && info "$str_usage" && exit 1

typeset -ri nr_files=$(find /u01 -type f | wc -l)
if [ $nr_files -ne 0 ]
then
	error "Le GI et oracle doivent être désinstallés."
	LN
	info "$str_usage"
	exit 1
fi

exec_cmd -c "userdel -r grid"
exec_cmd -c "userdel -r oracle"
LN

exec_cmd -c "rm -rf /u01"
LN

exec_cmd -c "rm -rf /root/.ssh"
LN

update_value IPADDR ${if_pub_network}.${master_ip_node}	$if_pub_file
LN

exec_cmd "echo ${master_name}.${infra_domain} > /etc/hostname"
LN

exec_cmd "sed -i '/\/mnt\/oracle_install/d' /etc/fstab"
LN

exec_cmd "~/plescripts/gadgets/customize_logon.sh -name=$master_name"
LN

exec_cmd "systemctl restart NetworkManager"
LN

if [ $EXEC_CMD_ACTION = NOP ]
then
	info "Use -doit to execute."
	LN
	info "$str_usage"
fi
