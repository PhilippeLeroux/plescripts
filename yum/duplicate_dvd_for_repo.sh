#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset	release=undef
typeset enable_repo=yes

typeset -r str_usage=\
"Usage :
$ME
	-release=DVD_R2|DVD_R3|DVD_R4
	[-enable_repo=$enable_repo]	yes or no
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-release=*)
			release=${1##*=}
			shift
			;;

		-enable_repo=*)
			enable_repo=${1##*=}
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

#ple_enable_log -params $PARAMS

exit_if_param_invalid release "DVD_R2 DVD_R3 DVD_R4" "$str_usage"

#	Function dupliquée de sync_oracle_repository.sh
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

info "Monte le DVD"
[ ! -d /mnt/cdrom ] && exec_cmd mkdir /mnt/cdrom || true

typeset -i	max_loops=10
while true
do
	exec_cmd -c mount /dev/cdrom /mnt/cdrom
	if [ $? -eq 0 ]
	then
		LN
		break
	elif [ $max_loops -eq 0 ]
	then
		error "Cannot mount /dev/cdrom"
		LN
		exit 1
	fi
	((--max_loops))
	sleep 1
done

typeset -r	repo_path="$infra_olinux_repository_path/$release"

info "Duplique les packages du DVD"
exec_cmd mkdir -p $repo_path
LN

exec_cmd "cp -pr /mnt/cdrom/Packages/* $repo_path/"
LN

exec_cmd mkdir $repo_path/repodata
LN

exec_cmd "cp -pr /mnt/cdrom/repodata/* $repo_path/repodata"
LN

info "Ejection du DVD"
exec_cmd umount /mnt/cdrom
exec_cmd eject
LN

if [ $enable_repo == yes ]
then
	info "Enable repository"
	exec_cmd ~/plescripts/yum/add_local_repositories.sh -role=infra
	LN
fi

fake_exec_cmd cd $repo_path
cd $repo_path
if ! command_exists createrepo
then
	exec_cmd -c yum -y -q install ./deltarpm-3.6-3.el7.x86_64.rpm
	exec_cmd -c yum -y -q install ./createrepo-0.9.9-26.el7.noarch.rpm
	exec_cmd -c yum -y -q install ./python-deltarpm-3.6-3.el7.x86_64.rpm
	LN
fi
exec_cmd createrepo --update $repo_path
fake_exec_cmd cd -
cd -
LN

if [ $enable_repo == yes ]
then
	exec_cmd ~/plescripts/yum/switch_repo_to.sh -local -release=$release
	LN
fi

nfs_export_repo
LN
