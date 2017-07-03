#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
$ME
	-device_list=name : ex sdb or \"sdb sdc\"
	-io_scheduler=noop|deadline|cfq create udev rule for device
"

typeset device_list=undef
typeset io_scheduler=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-device_list=*)
			device_list=${1##*=}
			shift
			;;

		-io_scheduler=*)
			io_scheduler=${1##*=}
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

exit_if_param_undef device_list "$str_usage"

exit_if_param_invalid io_scheduler "noop deadline cfq" "$str_usage"

typeset -r rules_filename=/etc/udev/rules.d/60-san-disk-schedulers.rules
if [ -f $rules_filename ]
then
	warning "File exists : $rules_filename"
	warning "Backup this file."
	exec_cmd cp $rules_filename /root/${rules_filename##*/}.back
	LN
fi

info "Create file $rules_filename"
for device in $device_list
do
	device=${device/\/dev\//}
	info "   device $device set io scheduler $io_scheduler"
	cat<<-EO_RULE>>$rules_filename
	ACTION=="add|change", KERNEL=="$device", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="$io_scheduler"
	EO_RULE
done
exec_cmd "cat $rules_filename"
LN

info "Reload rules"
exec_cmd udevadm control --reload-rules
exec_cmd udevadm trigger
LN

timing 5
LN
