#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

add_usage "-mount_point=name"		""
add_usage "-suffix_vglv=name"		"=> vg\$suffix, lv\$suffix"
add_usage "-cluster_name=name"		"ocfs2 cluster name"
add_usage "-action=create|add"		""
add_usage "[-device=check]"			"or full device name : /dev/sdb,/dev/sdc ..."
add_usage "[-disks=1]"				"number of disks, only if -device=check"
add_usage "[-striped=no]"			"no|yes"
add_usage "[-stripesize=#]"			"stripe size Kb."

typeset	-r	str_usage=\
"Usage :
$ME
$(print_usage)"


typeset		mount_point=undef
typeset		suffix_vglv=undef
typeset		cluster_name=undef
typeset		action=undef
typeset		device_list="check"
typeset		disks=1
typeset		striped=no
typeset		stripesize_kb=0

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-cluster_name=*)
			cluster_name=$(to_lower ${1##*=})
			shift
			;;

		-suffix_vglv=*)
			suffix_vglv=${1##*=}
			shift
			;;

		-mount_point=*)
			mount_point=${1##*=}
			shift
			;;

		-action=*)
			action=${1##*=}
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

		-striped=*)
			striped=$(to_lower ${1##*=})
			shift
			;;

		-stripesize=*)
			stripesize_kb=${1##*=}
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

exit_if_param_invalid	action "create add"		"$str_usage"
exit_if_param_undef		cluster_name			"$str_usage"
exit_if_param_undef		mount_point				"$str_usage"
exit_if_param_undef		suffix_vglv				"$str_usage"

if [[ $stripesize_kb -ne 0 && $striped == no ]]
then
	error "-stripesize_kb=$stripesize_kb but -striped=$striped"
	LN
	exit 1
fi

typeset	-r	vg_name=vg${suffix_vglv}
typeset	-r	lv_name=lv${suffix_vglv}

#	BUG doc Oracle il faut créer le FS avant d'ajouter le device dans le cluster.
if [ $action == create ]
then
	if [ "$device_list" == check ]
	then
		exec_cmd ~/plescripts/disk/create_vg.sh		\
						-suffix_vglv=$suffix_vglv	\
						-disks=$disks				\
						-striped=$striped			\
						-stripesize=$stripesize_kb
	else
		exec_cmd ~/plescripts/disk/create_vg.sh		\
						-suffix_vglv=$suffix_vglv	\
						-device="$device_list"		\
						-striped=$striped			\
						-stripesize=$stripesize_kb
	fi

	#	–T datafiles ne fonctionne pas.
	exec_cmd mkfs.ocfs2 -L "ocfs2_${mount_point##*/}" --fs-feature-level=max-features /dev/$vg_name/$lv_name
	LN
fi

exec_cmd o2cb add-heartbeat $cluster_name /dev/$vg_name/$lv_name
LN

#	Util pour le premier disque :
exec_cmd -c /sbin/o2cb.init enable
LN

exec_cmd mkdir -p $mount_point
LN

exec_cmd "echo \"/dev/mapper/$vg_name-$lv_name  $mount_point  ocfs2     relatime,_netdev,defaults  0 0\" >> /etc/fstab"
LN

exec_cmd mount $mount_point
LN
