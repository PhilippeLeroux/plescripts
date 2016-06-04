#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

typeset vg_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

exit_if_param_undef vg_name	"$str_usage"

if [ -d /dev/$vg_name ]
then
	exec_cmd "ls -rtl /dev/$vg_name > ~/plescripts/san/${vg_name}.link"
else
	exec_cmd -c "rm ~/plescripts/san/${vg_name}.link"
fi
