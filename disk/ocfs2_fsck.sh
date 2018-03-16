#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	device=/$orcl_disk

typeset	-r	str_usage=\
"Usage : $ME
	-db=name
	[-db_is_stopped]
	[-kill_only] ne fait que tué les process et ne s'exécute pas sur les autres nœuds.
	[-device=$device]

Le Grid Infra et la base doivent être démarrés.
"

typeset		db=undef
typeset		kill_only=no
typeset		db_is_stopped=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-device=*)
			device=${1##*=}
			shift
			;;

		-kill_only)
			kill_only=yes
			shift
			;;

		-db_is_stopped)
			db_is_stopped=yes
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

must_be_user root

exit_if_param_undef db "$str_usage"

ple_enable_log -params $PARAMS

if [ ! -d $device ]
then
	error "$device not exists."
	LN
	exit 1
fi

if [[ $kill_only == no && $db_is_stopped == no ]]
then
	line_separator
	exec_cmd -c srvctl stop database -db $(to_upper $db)
	LN
	sleep 3
fi

line_separator
info "$(hostname -s) : Kill process on $device"
while read command pid user rem
do
	[[ x"$command" == x || "$command" == COMMAND ]] && continue || true

	info "kill command $command of $user pid = $pid"
	exec_cmd -c "kill -9 $pid"
	LN
done<<<"$(lsof $device)"
LN

line_separator
info "$(hostname -s) : umount $device"
exec_cmd umount $device
LN

[ $kill_only == yes ] && exit 0 || true

line_separator
for srv in $gi_node_list
do
	exec_cmd "ssh -t root@$srv 'plescripts/disk/ocfs2_fsck.sh -db=$db -kill_only'"
	LN
done

line_separator
exec_cmd fsck -f -y $device
LN

line_separator
info "$(hostname -s) : mount $device"
exec_cmd mount $device
LN
exec_cmd rm -rf $device/lost+found/*
LN

line_separator
for srv in $gi_node_list
do
	info "$srv : mount $device"
	exec_cmd ssh -t root@$srv mount $device
	LN
done

if [ $db_is_stopped == no ]
then
	line_separator
	exec_cmd -c srvctl start database -db $(to_upper $db)
	LN
fi
