#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
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

exit_if_param_undef db	"$str_usage"

typeset vg_asm=asm01

typeset links_asm_path=/dev/$vg_asm

typeset all_devices=""
while read link_name
do
	all_devices=$all_devices" "$(readlink -f $link_name)
done<<<"$(ls -1 $links_asm_path/lv${db}*)"

exec_cmd "iostat -m 2 $all_devices"
