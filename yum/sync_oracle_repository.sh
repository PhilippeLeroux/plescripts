#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	[-copy_iso]        : Les ISO Linux Oracle seront copiés avant la synchronisation.
	[-only_nfs_update] : Met uniquement à jour l'export NFS.

	Synchronise le dépôt Oracle Linux.
"

info "$ME $@"

if [ "$(hostname -s)" != "$infra_hostname" ]
then
	error "Only on $infra_hostname"
	exit 1
fi

typeset	copy_iso=no
typeset	only_nfs_update=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-copy_iso)
			copy_iso=yes
			shift
			;;

		-only_nfs_update)
			only_nfs_update=yes
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

exit_if_param_undef mountpoint_iso_path	"$str_usage"

function copy_oracle_linux_iso
{
	typeset	-r	loop_directory=/tmp/mnt
	typeset -r	mountpoint_iso_path=/mnt/oracle_linux

	line_separator
	exec_cmd -c showmount -e $client_hostname
	LN

	exec_cmd -c showmount -e $client_hostname | grep -q $iso_olinux_path
	if [ $? -ne 0 ]
	then
		error "$client_hostname doit exporter $iso_olinux_path"
		exit 1
	fi

	[ ! -d $mountpoint_iso_path ] && exec_cmd mkdir $mountpoint_iso_path
	exec_cmd "mount $client_hostname:$iso_olinux_path $mountpoint_iso_path -t nfs -o ro,noatime,nodiratime,async"

	if [ ! -d $infra_olinux_repository_path ]
	then
		info "Create directory : $infra_olinux_repository_path"
		exec_cmd mkdir -p $infra_olinux_repository_path
	fi

	if [ ! -d $loop_directory ]
	then
		info "Create directory : $loop_directory"
		exec_cmd mkdir -p $loop_directory
	fi

	for iso_name in $mountpoint_iso_path/*.iso
	do
		info "mount $iso_name"
		exec_cmd mount -ro loop $iso_name $loop_directory
		LN
		info "Copy $iso_name to $infra_olinux_repository_path"
		exec_cmd rsync -avHPS $loop_directory $infra_olinux_repository_path
		LN
		exec_cmd umount $loop_directory
		LN
	done

	info "Remove $loop_directory"
	exec_cmd rm -rf $loop_directory
	LN
	info "Remove $mountpoint_iso_path"
	exec_cmd umount $mountpoint_iso_path
	exec_cmd rmdir $mountpoint_iso_path
	LN
}

function nfs_export_repo
{
	line_separator
	info "Exporte sur le réseau $infra_network $infra_olinux_repository_path"
	LN

	exec_cmd -c "grep -q \"$infra_olinux_repository_path\" /etc/exports >/dev/null 2>&1"
	if [ $? -ne 0 ]
	then
		exec_cmd "echo \"$infra_olinux_repository_path ${infra_network}.0/${infra_mask}(ro,async,no_root_squash,no_subtree_check)\" >> /etc/exports"
		exec_cmd exportfs -ua
		exec_cmd exportfs -a
		LN
	else
		info "NFS export [$OK]"
	fi
	exec_cmd exportfs
	LN
}

function update_yum_config
{
	typeset -r yum_file=~/plescripts/yum/public-yum-ol7.repo

	line_separator
	info "Mise à jour de $yum_file"
	exec_cmd "sed -i \"s!^baseurl.*!baseurl=file:///mnt$infra_olinux_repository_path!g\" $yum_file"
	LN
	exec_cmd cat $yum_file
	LN
}

if [ $only_nfs_update != yes ]
then
	[ "$copy_iso" == yes ] && copy_oracle_linux_iso

	line_separator
	exec_cmd -c reposync	--newest-only --download_path=$infra_olinux_repository_path \
							--repoid=ol7_latest

	exec_cmd createrepo $infra_olinux_repository_path
	LN
fi

nfs_export_repo
update_yum_config
