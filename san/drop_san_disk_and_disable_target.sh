#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r vg_name=asm01

typeset -r str_usage=\
"Usage : 
$ME
	-vg_name=$vg_name

Drop $vg_name and disable target.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

#ple_enable_log

script_banner $ME $*

info "Disks used by $vg_name"
exec_cmd "pvs | grep $vg_name"
LN

info "Remove vg $vg_name"
exec_cmd vgremove $vg_name
LN

info "Stop & disable target"
exec_cmd systemctl stop target.service
exec_cmd systemctl disable target.service
LN
