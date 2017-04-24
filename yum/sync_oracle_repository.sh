#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset	use_tar=none
typeset infra_install=no
typeset sync_repo_latest=yes
typeset	release=all

typeset -r str_usage=\
"Usage : $ME
\t[-use_tar=name] Initialise le dépôt avec \$use_tar
\t[-release=$release]	latest|R3|R4|all
\t[-skip_latest]

Sync local repository
"

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

		-infra_install)
			infra_install=yes
			shift
			;;

		-release=*)
			release=${1##*=}
			shift
			;;

		-skip_latest)
			sync_repo_latest=no
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

script_banner $ME $*

exit_if_param_invalid	release	"latest R3 R4 all"	"$str_usage"

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
		exec_cmd "echo \"$infra_olinux_repository_path $network/${if_pub_prefix}(ro,subtree_check)\" >> /etc/exports"
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
	exec_cmd -c reposync	--newest-only									\
							--download_path=$infra_olinux_repository_path	\
							--repoid=$repo_name
	if [ $? -ne 0 ]
	then
		if [ $infra_install == yes ]
		then
			# BUG : après installation du serveur d'infra le premier appel à
			# reposyn échoue (erreur python comme d'habitude), le second se passe
			# bien.

			# Il faut impérativement appelé abrt-cli pour contourner le bug.
			exec_cmd abrt-cli list
			LN

			exec_cmd reposync	--newest-only									\
								--download_path=$infra_olinux_repository_path	\
		 						--repoid=$repo_name
		else
			exit 1
		fi
	fi
	LN

	info "Update repository : $repo_name"
	test_if_cmd_exists createrepo
	[ $? -ne 0 ] && exec_cmd yum -y install createrepo
	exec_cmd createrepo --update $infra_olinux_repository_path/$repo_name
	LN
}

[ $infra_install == no ] && must_be_executed_on_server "$infra_hostname" || true

line_separator
if [ ! -d $infra_olinux_repository_path ]
then
	info "Create directory : $infra_olinux_repository_path"
	exec_cmd mkdir -p $infra_olinux_repository_path
	LN
fi

if [ "$use_tar" != none ]
then #	$use_tar contient le backup d'un dépôt OL7.
	info "Extract repository from $use_tar"
	# Lecture du répertoire parent (root dir)
	root_dir="/$(echo $infra_olinux_repository_path | cut -d/ -f2)"
	exec_cmd "gzip -dc \"$use_tar\" | tar -C \"$root_dir\" -xf -"
	LN
else
	[ $sync_repo_latest == yes ] && sync_repo ol7_latest || true

	case $release in
		R3|R4)
			sync_repo ol7_UEK$release
			;;
		all)
			sync_repo ol7_UEKR3
			sync_repo ol7_UEKR4
			;;
	esac
fi

nfs_export_repo
LN

line_separator
exec_cmd ~/plescripts/yum/add_local_repositories.sh -role=infra
LN
exec_cmd ~/plescripts/yum/switch_repo_to.sh -local -release=$release
LN

line_separator
if test_if_rpm_update_available
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
