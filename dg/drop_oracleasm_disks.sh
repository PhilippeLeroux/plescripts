#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
Supprime des disques d'oracleasm et du SAN.

	-db=<str>        : Identifiant de la base
	-nr_disk=<#>     : N° du premier disque.
	[-count=1]       : Nombre de disque à supprimer, par défaut 1.
	[-vg_name=asm01] : Nom du VG contenant les LUNs sur K2, par défaut asm01.
"

info "$ME $@"

typeset		db=undef
typeset	-i	nr_disk=-1
typeset -i	count=1
typeset	-r	vg_name=asm01

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

		-nr_disk=*)
			nr_disk=${1##*=}
			shift
			;;

		-count=*)
			count=${1##*=}
			shift
			;;

		-vg_name=*)
			vg_name=${1##*=}
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

exit_if_param_undef db		"$str_usage"
exit_if_param_undef nr_disk	"$str_usage"

[ $USER != root ] && error "Must be root !" && exit 1

typeset -r upper_db=$(to_upper $db)

function disk_is_candidat 
{
	exec_cmd -f -c su - grid -c "kfod | grep -q \"$1\>\""
}

line_separator
for i in $( seq $nr_disk $(( nr_disk + count - 1 )) )
do
	disk=$(printf "S1DISK%s%02d" $upper_db $i)
	disk_is_candidat $disk
	if [ $? -ne 0 ]
	then
		error "$disk n'est pas candidat !"
		exit 1
	fi

	exec_cmd oracleasm deletedisk $disk
	LN
done

line_separator
exec_cmd "~/plescripts/disk/remove_unused_partition.sh"
LN

line_separator
exec_cmd ssh root@K2 "~/plescripts/san/delete_db_lun.sh -db=$db -lun=$nr_disk -count=$count -vg_name=$vg_name"
LN

line_separator
typeset -r hostn=$(hostname -s)
olsnodes | while read server_name
do
	[ x"$server_name" == x ] && break || true	# Pas un RAC
	[ $hostn == $server_name ] && continue
	exec_cmd "ssh $server_name \". ./.profile; oracleasm scandisks\""
	LN
done

