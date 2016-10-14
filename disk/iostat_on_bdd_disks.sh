#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset	disk_list

info "Lecture des disques utilisés par la base :"
while read disk_name
do
	if [ x"$disk_name" == x ]
	then
		error "no disk name."
		exit 1
	fi

	info -n "Disque oracleasm : $disk_name <--> "
	os_disk=$(oracleasm querydisk -p $disk_name | tail -1 | cut -d: -f1)
	info -f "$os_disk"
	[ x"$disk_list" == x ] && disk_list=$os_disk || disk_list="$disk_list $os_disk"
done<<<"$(oracleasm listdisks)"
LN

exec_cmd iostat -k 2 $(echo $disk_list |tr " " "\n"|sort|tr "\n" " ")
