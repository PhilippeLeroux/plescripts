#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=name"

script_banner $ME $*

typeset		db=undef
typeset		install=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-install)
			install=yes
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


nr_disk=$(asmcmd lsdsk | grep -v "^Path" | sort | tail -1 | sed "s/.*\(..\)$/\1/")
if [ x"$nr_disk" == x ]
then
	typeset -i nr_disk=1
else
	typeset -i nr_disk=$(( 10#$nr_disk + 1 ))
fi

while read device
do
	[ x"$device" == x ] && exit || true
	oracle_label=$(printf "s1disk${db}%02d" $nr_disk)
	((++nr_disk))
	exec_cmd asmcmd afd_label $oracle_label $device
	LN
done<<<"$(get_unused_disks_without_partitions)"

info "Oracle disks :"
exec_cmd ~/plescripts/disk/check_disks_type.sh -orclonly
LN

#	Le script est utilisé lors de la création des serveurs avant que le grid
#	ne soit installé, donc test l'existence de kfod.
test_if_cmd_exists kfod
if [ $? -eq 0 ]
then
	info "Disks candidats :"
	exec_cmd su - grid -c kfod
	LN
fi
