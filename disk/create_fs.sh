#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

add_usage "-mount_point=name"	""
add_usage "-suffix_vglv=name"	"=> vg\$suffix, lv\$suffix"
add_usage "-type_fs=name"		""
add_usage "[-device=check]"		"or full device name : /dev/sdb,/dev/sdc ..."
add_usage "[-disks=1]"			"number of disks, only if -device=check"
add_usage "[-striped=no]"		"no|yes"
add_usage "[-stripesize=#]"		"stripe size Kb."
add_usage "[-noatime]"			"add option noatime to mount point options."
add_usage "[-netdev]"			"add _netdev to mount point options."
add_usage "[-nobarrier]"		"add nobarrier option (xfs)"

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)
"

typeset		mount_point=undef
typeset		device_list="check"
typeset		disks=1
typeset		striped=no
typeset		stripesize_kb=0
typeset		suffix_vglv=undef
typeset		type_fs=undef
typeset		noatime=no
typeset		netdev=no
typeset		nobarrier=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-mount_point=*)
			mount_point=${1##*=}
			shift
			;;

		-device=*)
			disks=0
			device_list="${1##*=}"
			shift
			;;

		-disks=*)
			disks=${1##*=}
			shift
			;;

		-suffix_vglv=*)
			suffix_vglv=${1##*=}
			shift
			;;

		-type_fs=*)
			type_fs=${1##*=}
			shift
			;;

		-striped=*)
			striped=$(to_lower ${1##*=})
			shift
			;;

		-stripesize=*)
			stripesize_kb=${1##*=}
			shift
			;;

		-netdev)
			netdev=yes
			shift
			;;

		-noatime)
			noatime=yes
			shift
			;;

		-nobarrier)
			nobarrier=yes
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

exit_if_param_invalid striped "yes no" "$str_usage"

exit_if_param_undef mount_point	"$str_usage"
exit_if_param_undef suffix_vglv	"$str_usage"
exit_if_param_undef type_fs		"$str_usage"

if [[ $stripesize_kb -ne 0 && $striped == no ]]
then
	error "-stripesize_kb=$stripesize_kb but -striped=$striped"
	LN
	exit 1
fi

typeset	-r	vg_name=vg${suffix_vglv}
typeset	-r	lv_name=lv${suffix_vglv}

if [ "$device_list" == check ]
then
	exec_cmd ~/plescripts/disk/create_vg.sh		\
					-suffix_vglv=$suffix_vglv	\
					-disks=$disks				\
					-striped=$striped			\
					-stripesize=$stripesize
else
	exec_cmd ~/plescripts/disk/create_vg.sh		\
					-suffix_vglv=$suffix_vglv	\
					-device="$device_list"		\
					-striped=$striped			\
					-stripesize=$stripesize
fi

exec_cmd mkfs -t $type_fs /dev/$vg_name/$lv_name
sleep 1
LN

exec_cmd mkdir -p $mount_point
LN

typeset mp_options="defaults"
[ $nobarrier == yes ] && mp_options="nobarrier,$mp_options" || true
[ $netdev == yes ] && mp_options="_netdev,$mp_options" || true
[ $noatime == yes ] && mp_options="noatime,$mp_options" || true
exec_cmd "echo \"/dev/mapper/$vg_name-$lv_name $mount_point $type_fs $mp_options 0 0\" >> /etc/fstab"
LN

exec_cmd mount $mount_point
LN
