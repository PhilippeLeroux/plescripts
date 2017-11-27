#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/stats/statslib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset db=undef
typeset	loop=yes
typeset date=undef
typeset	range_mn=1

typeset -r str_usage=\
"Usage : $ME
		[-db=name]
		[-range_mn=$range_mn]
		[-no_loop]
		[-start_at=HHhMM]    skip tt before HHhMM

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

		-range_mn=*)
			range_mn=${1##*=}
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

# HH:MM:SS
function time_to_secs
{
	typeset -r ti=$1

	IFS=':' read hour mn s<<<"$ti"
	compute "$hour*60*60 + $mn*60 + $s"
}


function set_to_last_date
{
	last_log_path=$(ls -d ${PLELOG_ROOT}/* | tail -1)
	date=${last_log_path##*/}
	info "set date to $date"
	LN
}

#	============================================================================
#	MAIN
#	============================================================================

test_if_cmd_exists gnuplot
if [ $? -ne 0 ]
then
	error "gnuplot n'est pas installé ou pas dans PATH."
	exit 1
fi

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)
cfg_load_node_info $db 1

[ $date == undef ] && set_to_last_date || true
typeset	-a server_list=( $cfg_server_name )
typeset	-r	log_name01=${PLELOG_ROOT}/$date/stats/uptime_${cfg_server_name}.log
if [ $max_nodes -eq 2 ]
then
	cfg_load_node_info $db 2
	server_list+=( $cfg_server_name )
	typeset	-r	log_name02=${PLELOG_ROOT}/$date/stats/uptime_${cfg_server_name}.log
fi


#	Lecture de l'heure de début des mesures
#	Lire la première ligne peut fausser le résulat donc lecture de la ligne 2 (là 3 avec le labe)
typeset -r	start_time=$(sed -n "3p" ${log_name01} | awk '{ print $3 }')

# Lecture de la seconde mesure (ligne 3 donc) pour déterminer le refresh rate.
typeset -r	second_time=$(sed -n "4p" ${log_name01} | awk '{ print $3 }')

# Fréquence de rafraîchissement :
debug "start_time  = $start_time"
debug "second_time = $second_time"
typeset		refresh_rate=1

# boxes lines linespoints points impulses histeps
# ok : points, histeps, linespoints
#typeset -r with="linespoints pointinterval $(( (5*60) / refresh_rate ))"
typeset -r with="histeps"
#typeset -r with="linespoints"

typeset	-r	fmt_time="%H:%M:%S"

typeset -r	plot_cmds=/tmp/uptime.plot.$$
#typeset -r	plot_cmds=/tmp/debug.txt
#https://www2.uni-hamburg.de/Wiss/FB/15/Sustainability/schneider/gnuplot/colors.htm

typeset -i line_to_skip=1

typeset graph_title="Load Avg/Mn"

if [ $loop == yes ]
then
	cmds="$(printf "pause $refresh_rate\nreread\nreplot\n")"
else
	cmds="pause -1"
fi

typeset -r stats_markers=$PLESTATS_PATH/stats_info.txt
typeset labels
if [ -f $stats_markers ]
then
	info "Fabrication des labels..."
	typeset -i	loop=0
	typeset -i	trans=400
	typeset	-ri	offset_trans=200
	while read action what tt
	do
		loop=loop+1
		w=unset
		case "$what" in
			grid_installation)		w="GI" ;;
			oracle_installation)	w="Orcl" ;;
			create_*)				w="${what##*_}" ;;
			*)	error "'$what' unknow !!!"	;;
		esac
		labels=$(printf "$labels\nset label \"$action $w\" at \"$tt\",$trans")
		[ $(( loop % 2 )) -eq 0 ] && trans=$(( trans + offset_trans ))
	done<$stats_markers
fi

typeset	-r	range_max_lines=$(( (range_mn * 60) / refresh_rate ))

plot01="\"< tail -n$range_max_lines ${log_name01}\"	using 4:14 with ${with}	title '${server_list[0]}' lt rgb \"blue\""
if [ x"$log_name02" != x ]
then
	plot01="$plot01, \"< tail -n$range_max_lines ${log_name02}\"	using 4:14 with ${with}	title '${server_list[1]}' lt rgb \"red\""
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
set xtic rotate by -90
$labels
plot	\
	$plot01
$cmds
EOS
#set ylabel 'Load Avg/mn'
#"< tail -n$range_max_lines ${log_name01}"	using 1:11 title 'Load Avg'	with ${with}	lt rgb "blue"
#"${log_name01}"	using 1:(\$2+\$4) title 'S Kb'	with ${with}	lt rgb "blue"

line_separator
cat $plot_cmds
LN

line_separator
info "Refresh rate $(fmt_seconds $refresh_rate)"
info "Range : ( ${range_mn}mn * 60 ) / ${refresh_rate}s = ${range_max_lines} last lines read from input file."
LN
info "Load file    ${log_name01}"
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
exit 0
#rm -rf nohup.out >/dev/null 2>&1
#nohup gnuplot $plot_cmds &
#info "My pid is $!"
