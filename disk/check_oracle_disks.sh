#/bin/bash

#	ts=4 sw=4

#	Vérifie l'état des disques oracleasm

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
EXEC_CMD_ACTION=EXEC

[ $USER != root ] && [ $USER != grid ] && error "Only root or grid can execute this script" && exit 1

typeset -i count_disks_checked=0

while read disk_name
do
	count_disks_checked=count_disks_checked+1

	info "Test $disk_name"
	if [ x"$disk_name" == x ]
	then
		error "no disk name."
		exit 1
	fi

	exec_cmd -f -ci oracleasm querydisk -p $disk_name
	if [ $? -ne 0 ]
	then
		error "error :"

		device_name=$(get_os_disk_used_by_oracleasm $disk_name)

		info "Le disque correspondant est :"
		exec_cmd -f -cont "ls -l $device_name"
	fi
	LN
done<<<"$(oracleasm listdisks)"

info "$count_disks_checked disks checked."
LN
