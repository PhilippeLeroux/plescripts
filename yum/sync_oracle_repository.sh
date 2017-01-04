#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
\t[-use_tar=name] Usage tar 'name' to create local repository.
\t[-release=$default_yum_repository_release]	latest|R3|R4

Update OS & sync local repository
"

script_banner $ME $*

must_be_executed_on_server "$infra_hostname"

typeset	use_tar=none
typeset	release=$default_yum_repository_release

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-use_tar=*)
			use_tar=${1##*=}
			shift
			;;

		-release=*)
			release=${1##*=}
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

exit_if_param_invalid	release	"latest R3 R4"	"$str_usage"

typeset	-r repo_config_path=/etc/yum.repos.d
typeset	-r repo_config_name=public-yum-ol7.repo

function nfs_export_repo
{
	line_separator
	info "NFS export : $infra_network $infra_olinux_repository_path"
	LN

	exec_cmd -c "grep -q \"$infra_olinux_repository_path\" /etc/exports"
	if [ $? -ne 0 ]
	then
		typeset	-r network=$(right_pad_ip $infra_network)
		exec_cmd "echo \"$infra_olinux_repository_path $network/${if_pub_prefix}(ro,async,no_root_squash,no_subtree_check)\" >> /etc/exports"
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

#	Le répertoire commun à tous les dépôts est : $infra_olinux_repository_path
#	Chaque dépôt a un ss-répertoire dans : $infra_olinux_repository_path
#	Le createrepo doit se faire sur chaque ss-répertoire et non pas sur le
#	répertoire $infra_olinux_repository_path
function sync_repo
{
	typeset -r repo_name="$1"

	info "Sync repository : $repo_name"
	if [ ! -d $infra_olinux_repository_path/$repo_name ]
	then
		exec_cmd mkdir -p $infra_olinux_repository_path/$repo_name
	fi
	exec_cmd reposync	--newest-only									\
						--download_path=$infra_olinux_repository_path	\
						--repoid=$repo_name
	LN

	info "Update repository : $repo_name"
	test_if_cmd_exists createrepo
	[ $? -ne 0 ] && exec_cmd yum -y install createrepo
	exec_cmd createrepo --update $infra_olinux_repository_path/$repo_name
	LN
}

must_be_executed_on_server "$infra_hostname"

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
	exec_cmd "gzip -dc \"${use_tar##*/}\" | tar xf -"
	exec_cmd rm "${use_tar##*/}"
	LN
else
	sync_repo ol7_latest

	case $release in
		R3|R4)
			sync_repo ol7_UEK$release
			;;
	esac
fi

nfs_export_repo
LN

line_separator
exec_cmd ~/plescripts/yum/add_local_repositories.sh -role=infra
#	Pour le serveur d'infra les dépôts R3 ou R4 ne doivent pas être activés, trop
#	de problème avec target.
exec_cmd ~/plescripts/yum/switch_repo_to.sh -local
LN

line_separator
test_if_rpm_update_available
if [ $? -eq 0 ]
then
	info "To update : yum update"
	LN
	info " * yum/update_master.sh to upadte VM $master_hostname, execute from $client_hostname"
	info " * yum/update_db_os.sh to update VM with bdd, execute from the bdd server."
	LN
else
	info "No update available."
	LN
fi
