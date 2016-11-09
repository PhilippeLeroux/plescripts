#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	[-force_sync]   Synchronise le dépôt locale même s'il n'y a pas de maj disponible.
	[-use_tar=name] Utilise l'archive 'name' pour créer le dépôt

Synchronise le dépôt Oracle Linux.
"

script_banner $ME $*

if [ "$(hostname -s)" != "$infra_hostname" ]
then
	error "Only on $infra_hostname"
	exit 1
fi

typeset	force_sync=no
typeset	use_tar=none

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-force_sync)
			force_sync=yes
			shift
			;;

		-use_tar=*)
			use_tar=${1##*=}
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

function nfs_export_repo
{
	line_separator
	info "Exporte sur le réseau $infra_network $infra_olinux_repository_path"
	LN

	exec_cmd -c "grep -q \"$infra_olinux_repository_path\" /etc/exports"
	if [ $? -ne 0 ]
	then
		exec_cmd "echo \"$infra_olinux_repository_path ${infra_network}.0/${if_pub_prefix}(ro,async,no_root_squash,no_subtree_check)\" >> /etc/exports"
		exec_cmd exportfs -ua
		exec_cmd exportfs -a
		LN
	else
		info "NFS export [$OK]"
		LN
	fi

	exec_cmd exportfs
	LN
}

function update_yum_repository_file
{
	typeset -r yum_file=~/plescripts/yum/public-yum-ol7.repo

	line_separator
	info "Mise à jour de $yum_file"
	exec_cmd "sed -i \"s!^baseurl.*!baseurl=file:///mnt$infra_olinux_repository_path!g\" $yum_file"
	LN
}

if [ $force_sync == no ]
then
	test_if_rpm_update_available
	[ $? -ne 0 ] && exit 0
	LN
fi

line_separator
info "Update $(hostname -s)"
exec_cmd yum -y update
LN

line_separator
if [ ! -d $infra_olinux_repository_path ]
then
	info "Create directory : $infra_olinux_repository_path"
	exec_cmd mkdir -p $infra_olinux_repository_path
	LN
fi

if [ "$use_tar" != none ]
then #	$use_tar contient le dépôt OL7 à partir de ol7, gains de temps dans les
	 #	testes. Cloner le dépôt prend une heure avec l'archive 2mn maximum.
	info "Extract repository from $use_tar"
	root_dir="/$(echo $infra_olinux_repository_path | cut -d/ -f2)"
	exec_cmd mv "$use_tar"	"$root_dir"
	fake_exec_cmd cd $root_dir
	cd "$root_dir"
	exec_cmd tar xf "${use_tar##*/}"
	exec_cmd rm "${use_tar##*/}"
	LN
fi

info "Sync local repository :"
exec_cmd -c reposync	--newest-only									\
						--download_path=$infra_olinux_repository_path	\
						--repoid=ol7_latest
LN

info "Load packages 2 remove."
typeset -r packages_2_remove="$(repomanage --old $infra_olinux_repository_path)"
if [ x"$packages_2_remove" == x ]
then
	info "no packages to remove."
else
	info "Remove old packages :"
	exec_cmd rm $(repomanage --old $infra_olinux_repository_path)
fi
LN

info "Update local repository :"
exec_cmd createrepo --update $infra_olinux_repository_path
LN

nfs_export_repo
LN

line_separator
info "Notes :"
info " * yum/update_master.sh met à jour la VM master $master_name, à exécuter depuis $client_hostname"
info " * yum/update_db_os.sh met à jour une VM de base de données, à exécuter sur le serveur."
LN
