#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"
typeset	-r	str_usage=\
"Usage :
$ME
	-fs=fs name
	[-node_list=node2,node3,...] For clustered VG
"

typeset		fs=undef
typeset	-a	node_list
typeset		keep_vg=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-fs=*)
			fs=${1##*=}
			shift
			;;

		-node_list=*)
			while IFS=',' read node_name
			do
				node_list+=( $node_name )
			done<<<"${1##*=}"
			shift
			;;

		-keep_vg)
			keep_vg=yes
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

exit_if_param_undef fs	"$str_usage"

if [ ! -d "$fs" ]
then
	error "mount point $fs not found."
	LN
	exit 1
fi

read vgname lvname<<<"$(grep "$fs" /etc/fstab | sed "s/\/dev\/mapper\/\(.*\)-\(.*\) \/.*/\1 \2/")"

if [ x"$vgname" == x ]
then
	error "vg not found."
	LN
	exit 1
fi

partition_list="$(pvs 2>/dev/null | grep $vgname | awk '{ print $1 }' | xargs)"

info "FS         : $fs"
info "VG         : $vgname"
info "LV         : $lvname"
info "Partitions : $partition_list"
LN

line_separator
info "umount $fs and remove $fs from /etc/fstab"
LN
if grep -q "$fs" /etc/fstab
then
	exec_cmd -c "umount $fs"
	LN

	exec_cmd "sed -i '/$(escape_slash $fs)/d' /etc/fstab"
	LN
else
	warning "$fs not found in /etc/fstab"
	LN

	info "try umount" # au cas ou
	exec_cmd -c "umount $fs"
	LN
fi

if [ ${#node_list[*]} -ne 0 ]
then
	line_separator
	info "Drop fs $fs on node(s) : ${node_list[*]}"
	LN

	for node_name in ${node_list[*]}
	do
		exec_cmd "ssh -t $node_name 'TERM=$TERM plescripts/disk/drop_fs.sh -fs=$fs -keep_vg'"
		LN
	done
fi

if [ $keep_vg == no ]
then
	line_separator
	exec_cmd "~/plescripts/disk/drop_vg.sh -vg=$vgname"
fi
