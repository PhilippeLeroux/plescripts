#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

typeset		db=undef
typeset	-i	ilun=1

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

		-ilun=*)
			ilun=${1##*=}
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

while read device
do
	[ x"$device" == x ] && exit
	add_partition_to $device
	part_name=${device}1
	oracle_label=$(printf "s1disk${db}%02d" $ilun)
	ilun=ilun+1
	timing 1 "Wait partition."
	exec_cmd "oracleasm createdisk $oracle_label ${part_name}"
	LN
done<<<"$(get_unused_disks)"

info "Oracle disks :"
oracleasm listdisks
LN
