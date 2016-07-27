#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME [-emul]"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

function vg_exists
{
	typeset -r vg_name=$1

	vgdisplay $vg_name >/dev/null 2>&1
}

function search_unused_disk
{
	while read odisk idisk
	do
		type_is="$(disk_type ${odisk}1)"
		if [ "$type_is" = "unused" ]
		then
			echo "$odisk"
			return 0
		fi
	done<<<"$(get_iscsi_disks)"
	return 1
}

function create_oracle_fs
{
	typeset -r db=$2

	typeset -r db_mount_point=/u01/app/oracle/oradata

	if [ -d $db_mount_point ]
	then
		error "fs $db_mount_point exists."
		return 1
	fi

	info "Scan new LUNs"
	exec_cmd iscsiadm -m node --rescan
	LN

	info "Search unused disk"
	disk=$(search_unused_disk)
	if [ $? -ne 0 ]
	then
		error "No disk available."
		return 1
	fi

	typeset -r part_name=${disk}1
	info "Use disk : $disk"
	info "  partition : $part_name"
	LN

	info "Create mount point"
	exec_cmd -c mkdir -p $db_mount_point
	LN

	typeset -r vg_name=vg_oradata
	typeset -r lv_name=lv_oradata
	info "Create vg $vg_name"
	exec_cmd "pvcreate $part_name"
	exec_cmd "vgcreate $vg_name $part_name"
	LN

	info "Create lv $lv_name"
	exec_cmd "lvcreate -y -l 100%FREE -n $lv_name $vg_name"
	LN

	info "Create fs type $rdbms_fs_type"
	exec_cmd "mkfs -t $rdbms_fs_type /dev/$vg_name/$lv_name"
	exec_cmd "echo \"/dev/mapper/$vg_name-$lv_name $db_mount_point $rdbms_fs_type defaults,_netdev 0 0\" >> /etc/fstab"
	exec_cmd "mount $db_mount_point"
	exec_cmd "chown -R oracle:oinstall $db_mount_point"
	LN
}

#create_oracle_fs
typeset -r db_mount_point=/u01/app/oracle/oradata

if [ -d $db_mount_point ]
then
	error "$db_mount_point exists."
	exit 1
fi

while read disk_name disk_num
do
	info "Disk $disk_nun : $disk_name"
	part_name=${disk_name}1
	if [ -b $part_name ]
	then
		exec_cmd -ci "pvs --noheadings | grep \"$part_name\" >/dev/null 2>&1"
		if [ $? -eq 0 ]
		then
			info "$part_name in used."
			LN
			continue
		fi

		info "$part_name available."
		LN

		info "Create mount point"
		exec_cmd -c mkdir -p $db_mount_point
		LN

		typeset vg_name=vg_oradata
		typeset lv_name=lv_oradata
		info "Create vg $vg_name"
		exec_cmd "pvcreate $part_name"
		exec_cmd "vgcreate $vg_name $part_name"
		LN

		info "Create lv $lv_name"
		exec_cmd "lvcreate -y -l 100%FREE -n $lv_name $vg_name"
		LN

		info "Create fs type $rdbms_fs_type"
		exec_cmd "mkfs -t $rdbms_fs_type /dev/$vg_name/$lv_name"
		exec_cmd "echo \"/dev/mapper/$vg_name-$lv_name $db_mount_point $rdbms_fs_type defaults,_netdev 0 0\" >> /etc/fstab"
		exec_cmd "mount $db_mount_point"
		exec_cmd "chown -R oracle:oinstall $db_mount_point"
		LN
		exit 0
	else
		info "Partition $part_name not exists."
		LN
	fi
done<<<"$(get_iscsi_disks)"

error "No partition available."
exit 1
