#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -vg=name"

typeset vg=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-vg=*)
			vg=${1##*=}
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

ple_enable_log -params $PARAMS

exit_if_param_undef vg	"$str_usage"

typeset -a partition_list
typeset -a vg_disk_list
while read f1 disk rem
do
	typeset -i ilastcar=${#disk}
	((--ilastcar))
	if [ ${disk:$ilastcar} == 1 ]
	then
		partition_list+=( $disk )
		vg_disk_list+=( ${disk:0:-1} )
	else
		vg_disk_list+=( ${disk} )
	fi
done<<<"$(pvscan 2>/dev/null|grep $vg)"

exec_cmd vgremove -f $vg 
LN

if [ ${#partition_list[@]} -ne 0 ]
then
	if [ ${#partition_list[@]} -ne ${#vg_disk_list[@]} ]
	then
		error "Partition #${#partition_list[@]} disks #${#vg_disk_list[@]}"
		error "Configuration not supported."
		LN
		exit 1
	fi

	line_separator
	for partition in ${partition_list[*]}
	do
		disk=${partition:0:-1}
		info "delete partition $partition from $disk"
		delete_partition $disk
		LN
		exec_cmd pvremove $partition
		LN
	done
fi

line_separator
for disk in ${vg_disk_list[*]}
do
	if [ ${#partition_list[@]} -eq 0 ]
	then
		exec_cmd pvremove $disk
		LN
	fi
	clear_device $disk
	LN
done
