#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME [-orclonly]"

must_be_user root

typeset showalldisks=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-orclonly)
			showalldisks=no
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

find /dev -regex "/dev/sd." | sort |\
while read disk idisk
do
	type="$(disk_type $disk)"
	typeset -i size_b=$(disk_size_bytes $disk)
	if [ "$type" = "unused" ]
	then
		if [ $showalldisks == yes ]
		then
			info -n "disk $disk $(fmt_bytesU_2_better $size_b) Unused."
		fi
	else
		if [[ $showalldisks == no && $type != oracleasm ]]
		then
			continue
		fi

		info -n "disk $disk $(fmt_bytesU_2_better $size_b) type $type"

		typeset -i nb_part=$(count_partition_for $disk)
		if [ $nb_part -ne 0 ]
		then
			echo ", partitions :"
			for (( ipart=1; ipart <= nb_part; ++ipart ))
			do
				part_name=${disk}$ipart
				part_type="$(disk_type $part_name)"
				info -n "	-$part_name type $part_type"
				case "$part_type" in
					oracleasm)
						desc=$(oracleasm querydisk $part_name)
						info -f " : ${desc##* }"
						;;
					LVM2_member)
						LN
						info "\tlsblk $part_name"
						lsblk $part_name | sed "s/^/\t\t/g"
						;;
					*)
						LN
						;;
				esac
			done
		else
			LN
			case "$part_type" in
				LVM2_member)
					info "\tlsblk $disk"
					lsblk $disk | sed "s/^/\t\t/g"
					;;
			esac
		fi
	fi
	LN
done
