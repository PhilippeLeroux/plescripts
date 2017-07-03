#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset		title=undef
typeset	-i	interval_secs=60
typeset		log=screen

add_usage "[-interval_secs=$interval_secs]"	"seconds"
add_usage "[-title=title]"
add_usage "[-log=$log]"					"screen|only|both"

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)
" 

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-interval_secs=*)
			interval_secs=${1##*=}
			shift
			;;

		-title=*)
			title=${1##*=}
			shift
			;;

		-log=*)
			log=${1##*=}
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

exit_if_param_invalid log "screen only both" "$str_usage"

if [ $log != none ]
then
	while [ ! -d $PLESTATS_PATH ]
	do
		echo "$PLESTATS_PATH not exists. sleep for 60s"
		sleep 60
	done

	if [ $title == undef ]
	then
		log_name="$PLESTATS_PATH/uptime_$(hostname -s).log"
	else
		log_name="$PLESTATS_PATH/uptime_$(hostname -s)_${title}.log"
	fi

	case $log in
		only)
			exec > $log_name 2>&1
			;;
		both)
			exec &> >(tee -a "$log_name")
			;;
	esac
fi

[ $title == undef ] && title="$(hostname -s)" || title="$(hostname -s) $title"

while true
do
	# Les traductions Fr sont vraiment à chier !
	echo "$title : $(LANG=C uptime)"
	sleep $interval_secs
done
