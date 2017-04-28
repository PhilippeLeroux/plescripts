#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage :
$ME
	-fs=fs name
"

typeset fs=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-fs=*)
			fs=${1##*=}
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

exit_if_param_undef fs	"$str_usage"

if [ ! -d "$fs" ]
then
	error "mount point $fs not found."
	LN
	exit 1
fi

read vgname lvname<<<"$(grep "$fs" /etc/fstab | sed "s/\/dev\/mapper\/\(.*\)-\(.*\) \/.*/\1 \2/")"

partition_list="$(pvs | grep $vgname | awk '{ print $1 }' | xargs)"
disk_list="$(sed "s/[1-9]//g"<<<"$partition_list")"

info "FS         : $fs"
info "VG         : $vgname"
info "LV         : $lvname"
info "Partitions : $partition_list"
info "Disks      : $disk_list"
LN

line_separator
info "umount $fs and remove $fs from /etc/fstab"
LN
if grep -q "$fs" /etc/fstab
then
	exec_cmd -c "umount $fs"
	LN

	exec_cmd "sed -i '/$(escape_slash $fs)/d' /etc/fstab"
	LN
else
	warning "$fs not found in /etc/fstab"
	LN

	info "try umount" # au cas ou
	exec_cmd -c "umount $fs"
	LN
fi

line_separator
info "Remove VG $vgname"
exec_cmd "vgremove --force $vgname"
LN

line_separator
info "Clear partitions"
for part_name in $partition_list
do
	clear_device "$part_name"
	LN
done

line_separator
info "Drop partitions and clear disks"
for disk_name in $disk_list
do
	delete_partition $disk_name
	LN
	clear_device $disk_name
	LN
done
