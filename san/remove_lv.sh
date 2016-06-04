#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/san/lvlib.sh

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME
	-vg_name     : nom du VG contenant les LVs.
	-prefix      : préfixe du nom des LVs.
	[-first_no]  : N° du premier LV. Si omis commence au premier.
	[-count]     : nombre de LV à supprimer, par défaut 1
	[-all]       : supprime tous les disques à partir de first_no
	               Si first_no est omis supprime tous les disques."

typeset		vg_name=undef
typeset		prefix=undef
typeset -i	first_no=-1
typeset -i	count=1
typeset		all=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-all)
			all=yes
			shift
			;;

		-prefix=*)
			prefix=${1##*=}
			shift
			;;

		-first_no=*)
			first_no=${1##*=}
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

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef vg_name		"$str_usage"
exit_if_param_undef prefix		"$str_usage"

if [ $all = yes ]
then
	load_lv_info $vg_name $prefix
	[ $first_no -eq -1 ] && first_no=10#$lv_first_no
	count=$(( 10#$lv_last_no - 10#$first_no + 1 ))
fi

exit_if_param_undef first_no	"$str_usage"

for i in $( seq 0 $(($count-1)) )
do
	lv_name=$(printf "lv%s%02d" $prefix $(($first_no+$i)))

	clear_device /dev/$vg_name/$lv_name 100000000
	LN

	info "remove : $lv_name"
	exec_cmd lvremove -y $vg_name/$lv_name
	LN
done

exec_cmd ~/plescripts/san/catch_vg_links.sh -vg_name=$vg_name

