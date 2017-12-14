#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage :
$ME
	[-d=0] default 0 is today.
	[-all] print all chronos."

typeset	-i	d=0

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-d=*)
			d=${1##*=}
			[ $d -lt 0 ] && d=$((-$d)) || true
			shift
			;;

		-all)
			d=99
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

typeset	-r	chrono_file=~/plescripts/tmp/scripts_chrono.txt

if [ ! -f $chrono_file ]
then
	error "$chrono_file not exists."
	LN
	exit 1
fi

if [ $d -eq 0 ]
then
	typeset	-r	today=$(date +%Y%m%d)
elif [ $d -ne 99 ]
then
	typeset	-ri	theday$(( $(date +%d) - d ))
	typeset	-r	today=$(date +%Y%m)$theday
fi

if [ $d -ne 99 ]
then # Filtre sur la date.
	filter_cmd="grep -E \"^$today\" $chrono_file"
else # Pas de filtre.
	filter_cmd="cat $chrono_file"
fi

typeset	prev_id=undef
while IFS=: read timestamp script_name id time_s time_f rem
do
	[ x$"timestamp" == x ] && continue || true

	id=$(to_lower $id)
	if [[ "$prev_id" != "$id" ]]
	then
		LN
		year=$(cut -c1-4<<<"$timestamp")
		month=$(cut -c5-6<<<"$timestamp")
		day=$(cut -c7-8<<<"$timestamp")
		prev_id=$id
		info "${UNDERLINE}$prev_id${NORM} : $year/$month/$day"
		info "    $(printf "%-30s" "Script name")   $(printf "%10s" "Time")"
	fi
	info "    $(printf "%-30s" $script_name) : $(printf "%10s" "$time_f")"
done<<<"$(eval $filter_cmd)"
LN
