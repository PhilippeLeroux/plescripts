#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset		db=undef
typeset		loop=yes
typeset		date=undef
typeset	-i	window_range_mn=20

typeset -r str_usage=\
"Usage : $ME
		[-db=name]
		[-window_range_mn=$window_range_mn]
		[-no_loop]
		[-date=YYYY-MM-DD]  default last log.

Display files produced by watch_uptime.sh with gnuplot"


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

		-window_range_mn=*)
			window_range_mn=${1##*=}
			shift
			;;

		-no_loop)
			loop=no
			shift
			;;

		-date=*)
			date=${1##*=}
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

[[ $db == undef && x"$ID_DB" != x ]] && db=$ID_DB || true
exit_if_param_undef db  "$str_usage"

# Recherche le répertoire de log le plus récent.
# initialise la variable date.
function set_to_last_date
{
	last_log_path=$(ls -d ${PLELOG_ROOT}/* | tail -1)
	date=${last_log_path##*/}
	info "set date to $date"
	LN
}

# $1 time : HH:MM:SS
# print to stdout seconds
function convert_to_seconds
{
	typeset	-i	lh
	typeset	-i	lm
	typeset	-i	ls

	IFS=':' read lh lm ls <<<"$1"

	echo $(( (lh * 60 * 60) + (lm * 60) + ls ))
}

#	============================================================================
#	MAIN
#	============================================================================

if ! command_exists gnuplot
then
	error "gnuplot n'est pas installé ou pas dans PATH."
	exit 1
fi

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)
cfg_load_node_info $db 1

[ $date == undef ] && set_to_last_date || true
typeset	-a	server_list=( $cfg_server_name )
typeset	-r	log_name01=${PLELOG_ROOT}/$date/stats/uptime_${cfg_server_name}.log
typeset	-a	boot_time_list=( $(head -1 "$log_name01"|awk '{print $3}') )
if [ $max_nodes -eq 2 ]
then
	cfg_load_node_info $db 2
	typeset	-r	log_name02=${PLELOG_ROOT}/$date/stats/uptime_${cfg_server_name}.log
	server_list+=( $cfg_server_name )
	boot_time_list+=( $(head -1 "$log_name02"|awk '{print $3}') )
fi

#	Lecture de l'heure de début des mesures
#	Lire la première ligne peut fausser le résulat donc lecture de la ligne 2 (là 3 avec le labe)
typeset -ri	start_time_s=$(convert_to_seconds $(sed -n "3p" ${log_name01} | awk '{ print $3 }'))

# Lecture de la seconde mesure (ligne 3 donc) pour déterminer le refresh rate.
typeset -ri	second_time_s=$(convert_to_seconds $(sed -n "4p" ${log_name01} | awk '{ print $3 }'))

typeset	-i	interval_s=$(( second_time_s - start_time_s ))
[ $interval_s -lt 60 ] && interval_s=60 || true

typeset	-i	refresh_rate_s=$(( interval_s / 2 ))

typeset	-r	max_measures=$(( $window_range_mn / ($interval_s/60) ))

# Fréquence de rafraîchissement :
info "window_range_mn = ${window_range_mn}mn ($(fmt_seconds $(($window_range_mn*60))))"
info "Compute interval :"
info "start_time      = $(fmt_seconds $start_time_s)"
info "second_time     = $(fmt_seconds $second_time_s)"
info "interval        = $(fmt_seconds $interval_s)"
info "refresh_rate_s  = $(fmt_seconds $refresh_rate_s) (interval/2)"
info "max_measures    = $(fmt_number $max_measures) (window_range_mn/interval)"
LN

# boxes lines linespoints points impulses histeps
# ok : points, histeps, linespoints
typeset -r	with="histeps"

typeset	-r	fmt_time="%H:%M"

typeset -r	plot_cmds=/tmp/uptime.plot.$$
#typeset -r	plot_cmds=/tmp/debug.txt

typeset -i line_to_skip=1

typeset graph_title="Load Avg/Mn"
graph_title="$graph_title : ${server_list[0]} boot time ${boot_time_list[0]}"
if [ ${#server_list[@]} -eq 2 ]
then
	graph_title="$graph_title, ${server_list[1]} boot time ${boot_time_list[1]}"
fi

if [ $loop == yes ]
then
	cmds="$(printf "pause $refresh_rate_s\nreread\nreplot\n")"
else
	cmds="pause -1"
fi

plot01="\"< tail -n$max_measures ${log_name01}\"	using 4:14 with ${with}	title '${server_list[0]}' lt rgb \"blue\""
if [ x"$log_name02" != x ]
then
	plot01="$plot01, \"< tail -n$max_measures ${log_name02}\"	using 4:14 with ${with}	title '${server_list[1]}' lt rgb \"red\""
fi
debug "plot01 :"
debug "   '$plot01'"
cat << EOS > $plot_cmds
set key autotitle columnhead
set grid
set datafile separator " "
set term qt title '${graph_title}' size 944,512
set title '${graph_title}'
set format x '$fmt_time'
set timefmt '$fmt_time'
set xdata time
set xlabel 'Time'
set xtic rotate by -0
$labels
plot	\
	$plot01
$cmds
EOS

line_separator
cat $plot_cmds
LN

line_separator
info "Window range ${window_range_mn}mn"
info "Refresh rate $(fmt_seconds $refresh_rate_s)"
LN

info "Load file    ${log_name01}"
if [ x"$log_name02" != x ]
then
	info "Load file    ${log_name02}"
fi
LN

line_separator
gnuplot $plot_cmds
info "gnuplot return $?"
if [ "$plot_cmds" != "/tmp/debug.txt" ]
then
	rm $plot_cmds
else
	info "Debug file not removed : $plot_cmds"
	LN
fi
