#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name

Remove all services for a pdb."

typeset db=undef
typeset service=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-pdb=*)
			pdb=$(to_lower ${1##*=})
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

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

typeset -i	count=0

while read label service rem
do
	[ x"$label" == x ] && continue

	exec_cmd "~/plescripts/db/drop_service.sh -db=$db -service=$service"
	LN
	count=count+1
done<<<"$(srvctl status service -db $db | grep -iE "(pdb){,1}${pdb}_.*")"
# (pdb){,1} nécessaire pour supprimer les services avec l'ancienne convention
# de nomage.

info "$count services removed."
LN
