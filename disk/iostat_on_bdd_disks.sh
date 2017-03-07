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

# Mémorise dans disk_list les disques utilisé par oracleasm.
function load_oracleasm_disks
{
	info "Lecture des disques utilisés par la base :"
	while read oralabel
	do
		if [ x"$oralabel" == x ]
		then
			error "no disk name."
			exit 1
		fi

		info -n "Disque oracleasm : $oralabel <--> "
		os_disk=$(oracleasm querydisk -p $oralabel | tail -1 | cut -d: -f1)
		info -f "$os_disk"
		[ x"$disk_list" == x ] && disk_list=$os_disk || disk_list="$disk_list $os_disk"
	done<<<"$(oracleasm listdisks)"
	LN
}

# Mémorise dans disk_list les disques utilisé par AFD.
function load_afd_disks
{
	info "Lecture des disques utilisés par la base :"
	for (( iloop=0; iloop < 5; ++iloop ))
	do
		while read oralabel filtering os_disk
		do
			if [ x"$oralabel" == x ]
			then
				error "loop #${iloop} no disk"
				timing 10 "Waiting asmcmd"
				LN
				break
			else
				iloop=10 # stop loop for
			fi

			info "Disque AFD : $oralabel <--> $os_disk"
			[ x"$disk_list" == x ] && disk_list=$os_disk || disk_list="$disk_list $os_disk"
		done<<<"$(asmcmd afd_lsdsk | grep ENABLED )"
		LN
	done
}

typeset	disk_list

if test_if_cmd_exists oracleasm
then
	load_oracleasm_disks
else
	load_afd_disks
fi

exec_cmd iostat -k 2 $(echo $disk_list |tr " " "\n"|sort|tr "\n" " ")
