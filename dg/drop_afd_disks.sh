#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset		db=undef
typeset	-i	nr_disk=-1
typeset -i	count=1
typeset	-r	vg_name=${infra_vg_name_for_db_luns}

typeset -r str_usage=\
"Usage : $ME
Supprime des disques oracle AFD (les LUNs sur le SAN sont supprimées).

	-db=name         : Identifiant de la base
	-nr_disk=#       : N° du premier disque.
	[-count=1]       : Nombre de disque à supprimer, par défaut 1.
	[-vg_name=$vg_name] : Nom du VG contenant les LUNs sur ${infra_hostname}.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-nr_disk=*)
			nr_disk=10#${1##*=}
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

must_be_user root

typeset -r upper_db=$(to_upper $db)

function disk_is_candidat
{
	exec_cmd -f -c su - grid -c "kfod | grep -q \"$1\>\""
}

line_separator
for (( i=nr_disk; i < nr_disk + count; ++i ))
do
	disk=$(printf "S1DISK%s%02d" $upper_db $i)
	if ! disk_is_candidat $disk
	then
		error "$disk is not candidat !"
		exit 1
	fi

	exec_cmd asmcmd afd_unlabel $disk
	LN
done

if [ $disks_hosted_by == san ]
then
	line_separator
	if [ $(dataguard_config_available) == yes ]
	then
		warning "Dataguard LUN not remove from $infra_hostname"
		LN
	else
		exec_cmd ssh -t root@$infra_hostname				\
						"~/plescripts/san/delete_db_lun.sh	\
										-db=$db				\
										-lun=$nr_disk		\
										-count=$count		\
										-vg_name=$vg_name"
		LN
	fi
else
	warning "Disks not removed form VBox : DIY"
	LN
fi
