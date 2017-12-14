#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset		device=undef
typeset	-i	tests=4

typeset -r str_usage=\
"Usage :
$ME
	-device=name ex : /dev/sdb
	[-tests=$tests]

run hdparm #$tests time on specified device.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-device=*)
			device="${1##*=}"
			shift
			;;

		-tests=*)
			tests="${1##*=}"
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

must_be_user root

exit_if_param_undef device	"$str_usage"

if ! command_exists hdparm
then
	info "Install hdparm"
	exec_cmd yum install hdparm -y
	LN
fi

typeset sum_read_mb=0
typeset	sum_seconds=0
typeset sum_mb_per_sec=0

# Timing O_DIRECT disk reads: 206 MB in  3.01 seconds =  68.43 MB/sec
for (( i=1; i <= tests; ++i ))
do
	read f1 f2 f3 f4 read_mb f6 f7 seconds f9 f10 mb_per_sec rem	\
				<<<"$(hdparm -t --direct $device | grep "Timing O_DIRECT")"

	info "Loop #$i $device $read_mb Mb $seconds secs : $mb_per_sec Mb/sec"

	sum_read_mb=$(( sum_read_mb + read_mb ))
	sum_seconds=$(compute -l2 $sum_seconds + $seconds)
	sum_mb_per_sec=$(compute -l2 $sum_mb_per_sec + $mb_per_sec)
done

mean_read_mb=$(compute -i "$sum_read_mb / $tests")
mean_seconds=$(compute -i "$sum_seconds / $tests")
mean_mb_per_sec=$(compute -i "$sum_mb_per_sec / $tests")

info "Loops #$tests direct I/Os on device $device :"
info "    reads   : $(fmt_number $mean_read_mb) Mb"
info "    seconds : $(fmt_seconds $mean_seconds)"
info "    Mb/sec  : $(fmt_number $mean_mb_per_sec)"
LN
