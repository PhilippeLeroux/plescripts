#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
Ce script vérifie le l'OS host remplie les conditions nécessaire au bon
fonctionnement de la démo."

info "$ME $@"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset -i bad_ip_host=0
typeset -i plescripts_ok=0
typeset -i zip_orcl_grid_ok=0
typeset -i unzipped_orcl_grid_ok=0
typeset -i iso_olinux_ok=0
typeset -i resolv_conf_ok=0
typeset -i vbox_is_ok=0

line_separator
info "L'addresse IP 192.170.100.1 correspond au poste client $client_hostname"
info -n "Test l'existence de l'IP 192.170.100.1 : "
ping -c 1 192.170.100.1 >/dev/null 2>&1
if [ $? -ne 0 ]
then
	info -f "[$KO]"
	error "Créer avec VirtualBox le réseau 192.170.100.1"
	bad_ip_host=1
else
	info -f "[$OK]"
fi
LN

line_separator
info -n "Test l'existence de '$HOME/plescripts' : "
if [ ! -d "$HOME/plescripts" ]
then
	info -f "[$KO]"
	error "	Ce répertoire doit contenir tous les scripts récupérés depuis GitHub."
	plescripts_ok=1
else
	info -f "[$OK]"
fi

if [ $type_shared_fs == nfs ]
then
	info -n "Test l'existence de '$HOME/ISO/$oracle_install' : "
	if [ ! -d "$HOME/ISO/$oracle_install" ]
	then
		info -f "[$KO]"
		error "	Ce répertoire doit contenir les zips d'Oracle et du Grid."
		zip_orcl_grid_ok=1
	else
		info -f "[$OK]"
	fi
	LN
fi

if [ $type_shared_fs == vbox ]
then
	info -n "Test l'existence de '$HOME/$oracle_install/database' : "
	if [ ! -d "$HOME/$oracle_install/database" ]
	then
		info -f "[$KO]"
		error "	Ce répertoire doit contenir les fichiers dézipés d'Oracle."
		unzipped_orcl_grid_ok=1
	else
		info -f "[$OK]"
	fi
	info -n "Test l'existence de '$HOME/$oracle_install/grid' : "
	if [ ! -d "$HOME/$oracle_install/grid" ]
	then
		info -f "[$KO]"
		error "	Ce répertoire doit contenir les fichiers dézipés du Grid."
		unzipped_orcl_grid_ok=1
	else
		info -f "[$OK]"
	fi
	LN
fi

if [ $type_shared_fs == nfs ]
then
	if [ $plescripts_ok -eq 0 ]
	then
		info "$client_hostname doit exporter via NFS les répertoires :"
		info -n "	- $HOME/plescripts : "
		grep "$HOME/plescripts" /etc/exports >/dev/null 2>&1
		plescripts_ok=$?
		[ $plescripts_ok -ne 0 ] && info -f "[$KO]" || info -f "[$OK]"
	fi

	if [ $zip_orcl_grid_ok -eq 0 ]
	then
		info -n "	- $HOME/ISO/$oracle_install : "
		grep "$HOME/ISO/$oracle_install" /etc/exports >/dev/null 2>&1
		zip_orcl_grid_ok=$?
		[ $zip_orcl_grid_ok -ne 0 ] && info -f "[$KO]" || info -f "[$OK]"
	fi
	LN
fi

line_separator
info -n "Test l'existence de $full_linux_iso_name : "
if [ ! -f "$full_linux_iso_name" ]
then
	info -f "[$KO]"
	error "L'ISO d'installation d'Oracle Linux 7 n'existe pas."
	iso_olinux_ok=1
else
	info -f "[$OK]"
fi
LN

line_separator
info "Validation de resolv.conf :"
info -n " - nameserver $infra_ip : "
if grep -q "^nameserver.*${infra_ip}" /etc/resolv.conf
then
	info -f "[$OK]"
else
	info -f "[$KO]"
	resolv_conf_ok=1
fi

info -n " - search $infra_domain .* : "
if grep -q "^search.*${infra_domain}.*" /etc/resolv.conf
then
	info -f "[$OK]"
else
	info -f "[$KO]"
	resolv_conf_ok=1
fi

LN

line_separator
info -n "Vbox dans le path : "
which VBoxManage >/dev/null 2>&1
if [ $? -ne 0 ]
then
	vbox_is_ok=1
	info -f "[$KO]"
else
	info -f "[$OK]"
fi

info -n "~/plescripts/shell dans le path : "
which llog >/dev/null 2>&1
if [ $? -ne 0 ]
then
	info -f "${LBLUE}non${NORM}, fortement conseillé..."
else
	info -f "[$OK]"
fi

LN


info "Positionne les acls sur ~/plescripts"
# Pour supprimer les acls : setfacl -Rb ~/plescripts/
exec_cmd setfacl -Rm d:g:users:rwx $HOME/plescripts
LN

line_separator
if [ $bad_ip_host -ne 0 ] 											\
	|| [ $plescripts_ok -ne 0 ] || [ $zip_orcl_grid_ok -ne 0 ] 		\
	|| [ $iso_olinux_ok -ne 0 ] || [ $unzipped_orcl_grid_ok -ne 0 ]	\
	|| [ $resolv_conf_ok -ne 0 ] 									\
	|| [ $vbox_is_ok -ne 0 ]
then
	info "Corriger les erreurs avant de continuer."
	exit 1
else
	info "Configuration conforme."
	exit 0
fi

