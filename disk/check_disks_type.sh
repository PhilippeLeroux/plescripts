#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
$ME
	[-afdonly] show only AFD disks
"

must_be_user root

typeset afdonly=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-afdonly)
			afdonly=yes
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

typeset	-i	nr_unused_disks=0

while read disk idisk
do
	type="$(disk_type $disk)"
	typeset -i size_b=$(disk_size_bytes $disk)
	if [ "$type" = "unused" ]
	then
		if [ $afdonly == no ]
		then
			info "disk $disk $(fmt_bytes_2_better $size_b) ${BLINK}${UNDERLINE}Unused${NORM}."
			((++nr_unused_disks))
		fi
	else
		typeset -i nb_part=$(count_partition_for $disk)
		if [ $nb_part -ne 0 ]
		then
			[ $afdonly == yes ] && continue || true
			info -n "disk $disk $(fmt_bytes_2_better $size_b) type $type"
			info -f ", partitions :"
			for (( ipart=1; ipart <= nb_part; ++ipart ))
			do
				part_name=${disk}$ipart
				part_type="$(disk_type $part_name)"
				info -n "	-$part_name type $part_type"
				case "$part_type" in
					oracleasm) # Utilisation d'oracleasm 12.1
						info -f " : $(label_of $part_name)"
						;;
					LVM2_member)
						LN
						info "\tlsblk -t $part_name"
						lsblk -t $part_name | sed "s/^/\t/g"
						;;
					*)
						LN
						;;
				esac
			done
		elif [ $type == oracleasm ]
		then # Utilisation de AFD : 12.2
			info -n "disk $disk $(fmt_bytes_2_better $size_b) type $type"
			info -f " : $(label_of $disk)"
		elif [ $afdonly == no ]
		then
			info "disk $disk $(fmt_bytes_2_better $size_b) type $type"
			info "\tlsblk -t $disk"
			lsblk -t $disk | sed "s/^/\t/g"
		else
			continue	# pour éviter le LN
		fi
	fi
	LN
done<<<"$(find /dev -regex "/dev/sd.*[^0-9]" | sort)"

info "$nr_unused_disks unused disk(s)."
LN
