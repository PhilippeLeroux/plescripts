#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"
typeset	-r	str_usage=\
"Usage : $ME -vg=name"

typeset		vg=undef

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

# Lecture des partitions du VG.
typeset -a partition_list
while read f1 disk rem
do
	[ x"$disk" == x ] && continue || true

	typeset -i ilastcar=${#disk}
	((--ilastcar))
	if [ ${disk:$ilastcar} == 1 ]
	then
		partition_list+=( $disk )
	fi
done<<<"$(pvscan 2>/dev/null|grep $vg)"

if [ ${#partition_list[*]} -eq 0 ]
then
	error "No disks found for vg $vg"
	LN
	exit 1
fi

info "${#partition_list[*]} disks for vg $vg"
LN

exec_cmd -c vgremove -f $vg 
ret=$?
LN
if [ $ret -ne 0 ]
then
	if command_exists clvmd
	then
		line_separator
		warning "Méthode bourrin"
		LN
		if [ ${#partition_list[@]} -ne 0 ]
		then
			for partition in ${partition_list[*]}
			do
				line_separator
				disk=${partition:0:-1}
				info "Clear partition $partition and disk $disk."
				clear_device $partition
				LN

				clear_device $disk
				LN
			done
		fi
		exec_cmd -c "partprobe && lvscan --cache && vgscan --cache 2>/dev/null"
		LN

		if vgs $vg | grep -q "$vg"
		then
			warning "Relancer le script $ME $PARAMS"
			LN
			exit 1
		fi

		warning "Reboot !"
		LN

		exit 0
	else
		error "vgremove failed."
		LN
		exit 1
	fi
fi

if [ ${#partition_list[@]} -ne 0 ]
then
	line_separator
	for partition in ${partition_list[*]}
	do
		disk=${partition:0:-1}
		info "delete partition $partition from $disk"
		exec_cmd pvremove $partition
		LN
		delete_partition $disk
		LN
		clear_device $disk
		LN
	done
fi
