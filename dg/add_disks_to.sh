#/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
$ME
	-name=name : DG name.
	-disks=#   : # disks to add.
"

typeset		name=undef
typeset -i	disks=-1

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

exit_if_param_undef name	"$str_usage"
exit_if_param_undef disks	"$str_usage"

if [ $disks -eq 0 ]
then
	error "Parameter -disks=$disks invalid."
	LN
	exit 1
fi

typeset -a size_list
typeset -a disk_list

if [ "$(grid_release)" == "12cR1" ]
then
	while read size disk_name rem
	do
		size_list+=( $(( size / 1024 )) )
		disk_list+=( $disk_name )
	done<<<"$(kfod nohdr=true op=disks)"
else
	while read size disk_name rem
	do
		size_list+=( $(( size / 1024 )) )
		disk_list+=( $disk_name )
	done<<<"$(kfod nohdr=true op=disks | grep AFD)"
fi

if [ $disks -gt ${#disk_list[@]} ]
then
	error "Request #$disks disks"
	error "Available #${#disk_list[@]} disks"
	LN
	exit 1
fi

function make_sql_cmd
{
	for (( i=1; i < disks; ++i ))
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

if [ $EXEC_CMD_ACTION == EXEC ]
then
	printf "set echo off\nset timin on\n$cmd\n" | sqlplus -s / as sysasm
fi
