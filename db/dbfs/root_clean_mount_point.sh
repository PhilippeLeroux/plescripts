#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage :
$ME
	-pdb=name
	-service=name
"

script_banner $ME $*

typeset pdb=undef
typeset service=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-service=*)
			service=${1##*=}
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

exit_if_param_undef pdb		"$str_usage"
exit_if_param_undef service	"$str_usage"

must_be_user root

execute_on_all_nodes rm -rf /mnt/$pdb
LN

execute_on_all_nodes "sed -i '/@$service/d' /etc/fstab"
LN
