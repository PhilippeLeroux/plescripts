#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -vg_name=<str>	: nom du VG devant recevoir les disques.
			 -prefix=<str> 	: préfixe du nom des LV.
			 -size_gb=<#>	: Taille des LVs en Gb.
			 -first_no=<#>	: N° du premier LV.
			 -count=<#>	    : nombre de LV à créer.

Note : Pour exporter les LVs, utiliser export_lv.sh"

typeset		vg_name=undef
typeset		prefix=undef
typeset -i	size_gb=-1
typeset -i	first_no=-1
typeset -i	count=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-prefix=*)
			prefix=${1##*=}
			shift
			;;

		-size_gb=*)
			size_gb=${1##*=}
			shift
			;;

		-first_no=*)
			first_no=10#${1##*=}
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

exit_if_param_undef prefix		"$str_usage"
exit_if_param_undef size_gb		"$str_usage"
exit_if_param_undef first_no	"$str_usage"
exit_if_param_undef count		"$str_usage"
exit_if_param_undef vg_name		"$str_usage"

for i in $( seq 0 $(( $count - 1 )) )
do
	lv_name=$(printf "lv%s%02d" $prefix $(($first_no+$i)))

	info "create : $lv_name"
	exec_cmd lvcreate -y -L ${size_gb}G -n $lv_name $vg_name
	LN
done

exec_cmd ~/plescripts/san/catch_vg_links.sh -vg_name=$vg_name
LN

info "Pour exporter le lv :"
info "./export_lv.sh -vg_name=$vg_name -prefix=$prefix -first_no=$first_no -count=$count -initiator_name=<nom ici>"
LN
