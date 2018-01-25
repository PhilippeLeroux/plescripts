#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME
	-suffix_vglv=name   => vg\$suffix, lv\$suffix
	[-device=check]     or full device name : /dev/sdb,/dev/sdc ...
	[-disks=1]          number of disks, only if -device=check
	[-striped=no]       no|yes
	[-stripesize=#]     stripe size Kb.
"

typeset	-a	device_list=( "check" )
typeset	-i	disks=1
typeset		striped=no
typeset	-i	stripesize_kb=0
typeset		suffix_vglv=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-device=*)
			disks=0
			device_list=()
			while IFS=',' read dev
			do
				device_list+=( $dev )
				((++disks))
			done<<<"${1##*=}"
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

exit_if_param_invalid striped "yes no" "$str_usage"

exit_if_param_undef suffix_vglv	"$str_usage"

if [[ $stripesize_kb -ne 0 && $striped == no ]]
then
	error "-stripesize_kb=$stripesize_kb but -striped=$striped"
	LN
	exit 1
fi

typeset	-r	vg_name=vg${suffix_vglv}
typeset	-r	lv_name=lv${suffix_vglv}

if [ "${device_list[0]}" == check ]
then
	info "Search $disks disks unused :"

	device_list=()

	typeset -i idisk=0
	while read device
	do
		[ x"$device" == x ] && break || true

		device_list+=( $device )
		((++idisk))
		[ $idisk -eq $disks ] && break || true
	done<<<"$(get_unused_disks_without_partitions)"

	info "Device found $idisk : ${device_list[*]}"
	LN
	if [ $idisk -ne $disks ]
	then
		error "Not enougth disks."
		LN
		exit 1
	fi
fi

info "Create VG $vg_name with devices ${device_list[*]}"
LN

# Il faut créer une partition, sinon on écrase l'en-tête des LUNs sur le SAN
# Avec les disques présentés par VBox pas de problème, mais pour être cohérent
# il y aura toujours une partition.
typeset -a partition_list
for device in ${device_list[*]}
do
	typeset partname=${device}1
	partition_list+=( $partname )
	add_partition_to $device
	sleep 1
	LN

	exec_cmd pvcreate -y $partname
	LN
done
sleep 1

exec_cmd vgcreate $vg_name ${partition_list[*]}
sleep 1
LN

if [ $striped == yes ]
then
	info "Create striped VG, strip size : $stripesize_kb Kb"
	LN
	options="-i${#partition_list[@]}"
	[ $stripesize_kb -ne 0 ] && options="$options -I$stripesize_kb" || true
else
	info "Create linear VG"
	LN
fi

exec_cmd lvcreate -y $options -l 100%FREE -n $lv_name $vg_name
sleep  1
LN
