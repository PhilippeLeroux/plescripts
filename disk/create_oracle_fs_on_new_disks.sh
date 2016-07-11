#!/bin/ksh

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
		type_is="$(disk_type $odisk)"
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
		warning "fs $db_mount_point exists."
		return 0
	fi

	info "Search unused disk"
	exec_cmd iscsiadm -m node --rescan
	disk=$(search_unused_disk)
	if [ $? -ne 0 ]
	then
		error "No disk available."
		return 1
	fi

	info "Use disk : $disk"
	LN

	info "Create mount point"
	exec_cmd -c mkdir -p $db_mount_point
	LN

	typeset -r vg_name=vg_oradata
	typeset -r lv_name=lv_oradata
	info "Create vg $vg_name"
	exec_cmd "pvcreate $disk"
	exec_cmd "vgcreate $vg_name $disk"
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

create_oracle_fs
