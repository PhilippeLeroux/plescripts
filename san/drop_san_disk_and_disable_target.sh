#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r vg_name=$infra_vg_name_for_db_luns

typeset -r str_usage=\
"Usage : 
$ME
	[-vg_name=$vg_name]

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

#ple_enable_log -params $PARAMS

typeset -a vg_disk_list
while read disk_name rem
do
	vg_disk_list+=( $disk_name )
done<<<"$(pvs|grep $vg_name)"

info "Disks used by $vg_name : ${vg_disk_list[*]}"
LN

line_separator
info "Remove vg $vg_name"
exec_cmd -c  vgremove $vg_name
LN

if [ ${#vg_disk_list[@]} -ne 0 ]
then
	line_separator
	for disk_name in ${vg_disk_list[*]}
	do
		clear_device $disk_name
		LN
	done
fi

line_separator
info "Stop & disable target"
exec_cmd systemctl stop target.service
exec_cmd systemctl disable target.service
LN
