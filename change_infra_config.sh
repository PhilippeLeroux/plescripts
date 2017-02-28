#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME

Servira pour les testes de création du master et du serveur d'infra.
Objectif pouvoir tester la création du serveur d'infra sans supprimer l'existant.
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

#ple_enable_log

script_banner $ME $*

# Liste des variables a modifier :
#	Serveur d'infra
#		infra_hostname
#		infra_network
#		hostifname
#		san_disk_size_g
#
#	Serveur master
#		master_hostname

#	$1 nom de la variable à renseigner
#	$2 Message à afficher
function ask_for_variable
{
	typeset -r 	var_name=$1
	typeset		var_value=$(eval echo \$$var_name)
	typeset -r 	msg=$2

	info "$msg"
	if [ x"$var_value" != x ]
	then
		str=$(escape_anti_slash "$var_value")
		info "Valeur actuelle : $str"
	fi
	info -n "Valeur : "
	read -r keyboard

	[ x"$keyboard" != x ] && var_value="$keyboard"

	eval "$var_name=$(echo -E '$var_value')"
}

info "Configuration du serveur d'infra"

infra_hostname_n=$infra_hostname
ask_for_variable infra_hostname_n "Nom du serveur d'infra"

infra_network_n=$infra_network
ask_for_variable infra_network_n "Réseau"

hostifname_n=$hostifname
ask_for_variable hostifname_n "Nom de l'interface VirtualBox"

san_disk_size_g_n=$san_disk_size_g
ask_for_variable san_disk_size_g_n "Taille du disque SAN (Gb)"
LN

info "Configuration du master"
master_hostname_n=$master_hostname
ask_for_variable master_hostname_n "Nom du master"
LN

typeset count_errors=0

info "Nouvelle configuration :"
if [ $infra_hostname_n == $infra_hostname ]
then
	info -n "$KO"
	((++count_errors))
else
	info -n "$OK"
fi
info -f " : nom du serveur d'infra    $infra_hostname_n"

if [ $infra_network_n == $infra_network ]
then
	info -n "$KO"
	((++count_errors))
else
	info -n "$OK"
fi
info -f " : réseau                    $infra_network_n"

if [ $hostifname_n == $hostifname ]
then
	info -n "$KO"
	((++count_errors))
else
	info -n "$OK"
fi
info -f " : nom de l'interface VBox   $hostifname_n"

if [ $master_hostname_n == $master_hostname ]
then
	info -n "$KO"
	((++count_errors))
else
	info -n "$OK"
fi
info -f " : nom du master             $master_hostname_n"
LN

if [ $count_errors -ne 0 ]
then
	error "$count_errors erreurs."
	error "Il est impératif de changer tous les noms."
	LN
	exit 1
fi

info "Backup de global.cfg"
LN

exec_cmd "cp ~/plescripts/global.cfg ~/plescripts/global.cfg.infra_ori"
LN

info "Applique les modifications."
LN

exec_cmd "sed -i 's/infra_hostname=.*/infra_hostname=$infra_hostname_n/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/infra_network=.*/infra_network=$infra_network_n/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/hostifname=.*/hostifname=$hostifname_n/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/san_disk_size_g=.*/san_disk_size_g=$san_disk_size_g_n/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/master_hostname=.*/master_hostname=$master_hostname_n/g' ~/plescripts/global.cfg"
LN
