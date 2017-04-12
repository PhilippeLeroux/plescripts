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

# Mémorise dans disk_list tous les disques de l'OS.
function load_all_disks
{
	disk_list="$(find /dev -name "sd*" | grep -E "sd.*[a-z]$")"
}

# Mémorise dans disk_list les disques utilisés par oracleasm.
# Si aucun disques trouvé appel load_all_disks
function load_oracleasm_disks
{
	while read oralabel
	do
		[ x"$oralabel" == x ] && break || true

		info -n "Disque oracleasm : $oralabel <--> "
		os_disk=$(oracleasm querydisk -p $oralabel | tail -1 | cut -d: -f1)
		info -f "$os_disk"
		[ x"$disk_list" == x ] && disk_list=$os_disk || disk_list="$disk_list $os_disk"
	done<<<"$(oracleasm listdisks)"
	LN
	
	if [ x"$disk_list" == x ]
	then
		info "No oracleasm disks found."
		load_all_disks
		LN
	fi
}

# Mémorise dans disk_list les disques utilisés par AFD.
# Si aucun disques trouvé appel load_all_disks
function load_afd_disks
{
	for (( iloop=0; iloop < 5; ++iloop ))
	do
		while read oralabel filtering os_disk
		do
			if [ x"$oralabel" == x ]
			then
				error "loop #${iloop} no disk"
				timing 10 "Waiting asmcmd"
				break
			else
				iloop=10 # stop loop for
			fi

			info "Disque AFD : $oralabel <--> $os_disk"
			[ x"$disk_list" == x ] && disk_list=$os_disk || disk_list="$disk_list $os_disk"
		done<<<"$(asmcmd afd_lsdsk | grep ENABLED )"
		LN
	done

	if [ x"$disk_list" == x ]
	then
		info "No AFD disks found."
		load_all_disks
		LN
	fi
}

typeset	disk_list

info "Lecture des disques utilisés par la base :"
if [ $iostat_on == ALL ]
then
	load_all_disks
else
	if test_if_cmd_exists oracleasm
	then
		load_oracleasm_disks
	elif test_if_cmd_exists asmcmd
	then
		load_afd_disks
	else
		load_all_disks
	fi
fi

exec_cmd iostat -k 2 $(echo $disk_list |tr " " "\n"|sort|tr "\n" " ")
