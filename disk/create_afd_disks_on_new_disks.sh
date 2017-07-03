#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -db=name"

typeset		db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
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

exit_if_param_undef	db	"$str_usage"

must_be_user grid

nr_disk=$(asmcmd afd_lsdsk | grep "^S" | sort | tail -1 | awk '{ print $1 }' | sed "s/.*\(..\)$/\1/")
if [ x"$nr_disk" == x ]
then
	typeset -i nr_disk=1
else
	typeset -i nr_disk=$(( 10#$nr_disk + 1 ))
fi

while read device
do
	if [ x"$device" == x ]
	then
		error "no device found."
		exit 1
	fi
	oracle_label=$(printf "s1disk${db}%02d" $nr_disk)
	((++nr_disk))
	info "Create AFD label $oracle_label on disk $device"
	exec_cmd chown grid:asmadmin $device
	exec_cmd asmcmd afd_label $oracle_label $device
	LN
done<<<"$(get_unused_disks_without_partitions)"

info "Oracle disks :"
exec_cmd ~/plescripts/disk/check_disks_type.sh -afdonly
LN

info "Disks candidats :"
exec_cmd su - grid -c kfod
LN
