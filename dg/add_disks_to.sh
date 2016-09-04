#/bin/bash

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -name=<str> -disks=<#>
	-name  : nom du DG dans lequel ajouter des disques.
	-disks : nombre de disques à ajouter."

typeset		name=undef
typeset -i	disks=-1

while [ $# -ne 0 ]
do
	case $1 in
		-name=*)
			name=${1##*=}
			shift
			;;

		-disks=*)
			disks=${1##*=}
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

exit_if_param_undef name	"$str_usage"
exit_if_param_undef disks	"$str_usage"

typeset -a size_list
typeset -a disk_list

while read size disk
do
	[ x"$disk" == x ] && continue

	i=${#size_list[@]}
	typeset -i size_gb=$size
	size_gb=size_gb/1024
	size_list[$i]=$size_gb
	disk_list[$i]=$disk
done<<<"$(kfod nohdr=true op=disks)"

if [ $disks -gt ${#disk_list[@]} ]
then
	error "Demande de $disks disks"
	error "Disponible ${#disk_list[@]} disks"
	exit 1
fi

function make_sql_cmd
{
	for i in $(seq 1 $(( $disks - 1 )) )
	do
		other_disks="$other_disks\n,   '${disk_list[$i]}'"
	done
	cat <<EOS
alter diskgroup $name add
disk
    '${disk_list[0]}'$other_disks
;
EOS
}

cmd=$(printf "$(make_sql_cmd)\n")

fake_exec_cmd sqlplus -s / as sysasm
printf "$cmd\n"

printf "set echo off\nset timin on\n$cmd\n" | sqlplus -s / as sysasm
