#/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -name<str> -disks=<#>
	-name    : nom du DG à créer.
	-disks   : nombre de disques à utiliser.
	-nomount : ne monte pas le DG sur les autres nœuds.
"

typeset		name=undef
typeset -i	disks=-1

typeset		mount_on_other_nodes=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-name=*)
			name=${1##*=}
			shift
			;;

		-disks=*)
			disks=${1##*=}
			shift
			;;

		-nomount)
			mount_on_other_nodes=no
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

while read size disk_name
do
	size_list+=( $(( size / 1024 )) )
	disk_list+=( $disk_name )
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
create diskgroup $name external redundancy
disk
    '${disk_list[0]}'$other_disks
attribute
    'compatible.asm' = '12.1.0.2.0'
,   'compatible.rdbms' = '12.1.0.2.0'
;
EOS
}

cmd=$(printf "$(make_sql_cmd)\n")

fake_exec_cmd sqlplus -s / as sysasm
printf "$cmd\n"

if [ $EXEC_CMD_ACTION == EXEC ]
then
	printf "set echo off\nset timin on\n$cmd\n" | sqlplus -s / as sysasm
fi
LN

if [ $mount_on_other_nodes == yes ]
then
	typeset -r hostn=$(hostname -s)
	olsnodes | while read server_name
	do
		[ x"$server_name" == x ] && break || true	# Pas un RAC
		[ $hostn == $server_name ] && continue
		exec_cmd "ssh $server_name \". ./.profile; asmcmd mount $name\""
		LN
	done
fi
