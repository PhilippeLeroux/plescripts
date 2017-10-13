#/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/usagelib.sh
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset -r PARAMS="$*"

typeset	-r	gridversion=$(grid_version)

typeset		name=undef
typeset -i	disks=-1
typeset		compat_asm=$gridversion
typeset		compat_rdbms=$gridversion

typeset		mount_on_other_nodes=yes

add_usage "-name=name"						"DG name."
add_usage "-disks=#"						"Number disks."
add_usage "[-nomount]"						"No mount DG on other nodes."
add_usage "[-compat_asm=$compat_asm]"		"Attribute compatible.asm."
add_usage "[-compat_rdbms=$compat_rdbms]"	"Attribute compatible.rdbms."

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)
"

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

		-compat_asm=*)
			compat_asm=${1##*=}
			shift
			;;

		-compat_rdbms=*)
			compat_rdbms=${1##*=}
			shift
			;;

		-nomount)
			mount_on_other_nodes=no
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

typeset -a size_list
typeset -a disk_list

case "$gridversion" in
	12.1*)
		while read size disk_name rem
		do
			size_list+=( $(( size / 1024 )) )
			disk_list+=( $disk_name )
		done<<<"$(kfod nohdr=true op=disks)"
		;;
	*)	# A partir de la 12.2 AFD.
		while read size disk_name rem
		do
			size_list+=( $(( size / 1024 )) )
			disk_list+=( $disk_name )
		done<<<"$(kfod nohdr=true op=disks | grep AFD)"
		;;
esac

if [ $disks -gt ${#disk_list[@]} ]
then
	error "Request #$disks disks"
	error "Available #${#disk_list[@]} disks"
	LN
	info "With root :"
	info "$ cd ~/plescripts/disk"
	case "$gridversion" in
		12.1*)
			info "$ ./create_oracleasm_disks_on_new_disks.sh -db=<db id>"
			;;
		*)	# A partir de la 12.2 AFD.
			info "$ ./create_afd_disks_on_new_disks.sh -db=<db id>"
			;;
	esac
	LN
	exit 1
fi

function make_sql_create_diskgroup
{
	typeset other_disks # other_disks mémorise tous les disques sauf le premier.
	for (( i=1; i < disks; ++i ))
	do
		other_disks="$other_disks\n,   '${disk_list[i]}'"
	done

	cat <<EOS
create diskgroup $name external redundancy
disk
    '${disk_list[0]}'$other_disks
attribute
    'compatible.asm' = '$compat_asm'
,   'compatible.rdbms' = '$compat_rdbms'
;
EOS
}

sql_create_diskgroup=$(printf "$(make_sql_create_diskgroup)\n")

fake_exec_cmd sqlplus -s / as sysasm
printf "$sql_create_diskgroup\n"

if [ $EXEC_CMD_ACTION == EXEC ]
then
	printf "set echo off\nset timin on\n$sql_create_diskgroup\n" | sqlplus -s / as sysasm
fi
LN

if [ $mount_on_other_nodes == yes ]
then
	for node_name in ${gi_node_list[*]}
	do
		exec_cmd "ssh $node_name \". .bash_profile; asmcmd mount $name\""
		LN
	done
fi
