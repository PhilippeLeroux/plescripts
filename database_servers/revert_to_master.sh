#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=NOP

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-doit] [-force]
	Le GI et le logiciel Oracle doivent avoir été désinstallés.

	- Supprime les comptes oracle & grid.
	- Renomme le serveur en $master_name
	- Positionne l'IP ${if_pub_network}.${master_ip_node} sur $if_pub_name
	- Supprime de /etc/fstab : /mnt/oracle_install

	Le paramètre -force permet de ne pas tester si le Grid Infra est installé.
"

info "Running : $ME $*"

typeset force=no

while [ $# -ne 0 ]
do
	case $1 in
		-doit)
			EXEC_CMD_ACTION=EXEC
			shift
			;;

		-force)
			force=yes
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

typeset -i nr_files=0
if [ $force == no ]
then
	[[ -v GRID_HOME && -d $GRID_HOME ]] && nr_files=$(ls -1 $GRID_HOME | wc -l)
	info "$nr_files fichiers dans '$GRID_HOME'"
	if [ $nr_files -ne 0 ]
	then
		error "GI & Oracle software must be installed."
		LN
		info "$str_usage"
		exit 1
	fi
fi

line_separator
exec_cmd "~/plescripts/disk/logout_sessions.sh"
LN

line_separator
indo "Cleaning /etc/hosts"
exec_cmd "sed -i "/${infra_network}/d" /etc/hosts"
exec_cmd "sed -i "/${if_priv_network}/d" /etc/hosts"
exec_cmd "sed -i "/This/d" /etc/hosts"
exec_cmd "sed -i "/Other/d" /etc/hosts"
exec_cmd "sed -i "/Scan/d" /etc/hosts"
exec_cmd "sed -i "/^$/d" /etc/hosts"
LN

line_separator
info "Remove Oracle users."
exec_cmd "~/plescripts/oracle_preinstall/remove_oracle_users_and_groups.sh"

line_separator
exec_cmd -c "rm -rf /u01"
LN

line_separator
info "Remove symlink"
exec_cmd -c "rm ~/disk ~/yum"
LN

line_separator
info "Set master config"
update_value IPADDR ${if_pub_network}.${master_ip_node}	$if_pub_file
LN

exec_cmd "echo ${master_name}.${infra_domain} > /etc/hostname"
LN

exec_cmd "sed -i '/\/mnt\/oracle_install/d' /etc/fstab"
LN

exec_cmd "~/plescripts/gadgets/customize_logon.sh -name=$master_name"
LN

exec_cmd "rm -rf /tmp/*"
LN

line_separator
info "Désactive le service PLE Statistics"
exec_cmd -c "systemctl stop plestatistics"
exec_cmd -c "systemctl disable plestatistics"
exec_cmd -c "rm /usr/lib/systemd/system/plestatistics.service"
LN

line_separator
exec_cmd "systemctl restart NetworkManager"
LN

line_separator
info "Run ./clean_up_infra.sh -db=loulou from the host server before to start a new installation."
LN

if [ $EXEC_CMD_ACTION == NOP ]
then
	info "Use -doit to execute."
	LN
	info "$str_usage"
fi
