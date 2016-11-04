#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/san/targetclilib.sh
EXEC_CMD_ACTION=EXEC

. ~/plescripts/global.cfg

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
		-initiator_name : nom de l'initiateur
		-vg_name        : nom du VG contenant les LV
		-prefix         : préfixe du nom des LV.
		-first_no       : N° du premier LV.
		-count          : nombre de LV à exporter

		[-no_backup]    : A utiliser quand le backup est effectué par un autre script qui effectura le backup.

Note : les disques doivent avoir été crées avec create_lv.sh"

typeset		initiator_name=undef
typeset		vg_name=undef
typeset		prefix=undef
typeset -i	first_no=-1
typeset -i	count=-1
typeset		do_backup=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-initiator_name=*)
			initiator_name=${1##*=}
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

		-no_backup)
			do_backup=no
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

exit_if_param_undef initiator_name	"$str_usage"
exit_if_param_undef prefix			"$str_usage"
exit_if_param_undef size_gb			"$str_usage"
exit_if_param_undef first_no		"$str_usage"
exit_if_param_undef count			"$str_usage"
exit_if_param_undef vg_name			"$str_usage"

set_working_vg $vg_name

info "Create backstore"
create_backstore_range $first_no $count lv$prefix
LN

info "Create luns"
create_lun_range $first_no $count $initiator_name lv$prefix
LN

[ $do_backup == yes ] && exec_cmd ~/plescripts/san/save_targetcli_config.sh -name="after_export_lv" || true
