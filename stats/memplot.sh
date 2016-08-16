#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
		[-node=<#>]
		[-no_loop]
		[-title=<str>]
		[-date=<YYYY-MM-DD>] not set, search last date.
		[-time=<HHhMM>]      not set, search last time.
		[-server=<name>]     can be omitted with only one server.
		[-start_at=HHhMM]    skip tt before HHhMM
		[-show_log_only]     show log files.

Display files produced by memstats.sh with gnuplot"

typeset node=-1
typeset	loop=yes
typeset date=undef
typeset time=undef
typeset server=""
typeset title=""
typeset show_log_only=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-node=*)
			node=${1##*=}
			shift
			;;

		-no_loop=*)
			loop=no
			shift
			;;

		-date=*)
			date=${1##*=}
			shift
			;;

		-time=*)
			time=${1##*=}
			shift
			;;

		-title=*)
			title=${1##*=}_
			shift
			;;

		-server=*)
			server=${1##*=}_
			shift
			;;

		-show_log_only)
			show_log_only=yes
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

# HH:MM:SS
function time_to_secs
{
	typeset -r ti=$1

	IFS=':' read hour mn s<<<"$ti"
	compute "$hour*60*60 + $mn*60 + $s"
}

typeset log_shm=undef
typeset log_mem=undef
typeset log_swap=undef

function set_to_last_date
{
	last_log_path=$(ls -d ${PLELOG_ROOT}/* | tail -1)
	date=${last_log_path##*/}
	info "set date to $date"
	LN
}

function show_formatted_logs
{
	typeset log_mem=${PLELOG_ROOT}/$date/*${server}${title}memstat.log
	for f in $log_mem
	do
		IFS='_' read log_time srvname title1 rem<<<"${f##*/}"
		typeset msg=$(printf "$ME -title=%s -server=%s -time=%s" ${title1} $srvname $log_time)
		info "$msg"
	done
	LN
}

function make_log_names
{
	if [ $node -ne -1 ]
	then
		if [[ ! -v ID_DB ]]
		then
			error "set_db must be used with -node"
			exit 1
		fi

		if [ x"$server" != x ]
		then
			error "-node & -server cannot be used together."
			exit 1
		fi

		server=$(printf "srv%s%02d" $ID_DB $node)
	fi

	[ $date == undef ] && set_to_last_date

	if [ $time == undef ]
	then
		debug "ls -rt ${PLELOG_ROOT}/$date/*${server}*${title}shmstat.log"
		last_log_file=$(ls -rt ${PLELOG_ROOT}/$date/*${server}*${title}shmstat.log 2>/dev/null)
		[ x"$last_log_file" = x ] && error "File not found in ${PLELOG_ROOT}/$date" && exit 1

		IFS=_ read time server title rem<<<${last_log_file##*/}
		info "set time to   $time"
		info "set server to $server"
		info "set title to  $title"
		LN

		log_shm=$(ls -rt ${PLELOG_ROOT}/$date/${time}_${server}*shmstat.log)
		log_mem=$(ls -rt ${PLELOG_ROOT}/$date/${time}_${server}*memstat.log)
		log_swap=$(ls -rt ${PLELOG_ROOT}/$date/${time}_${server}*swapstat.log)
	fi

	if [ $log_shm == undef ]
	then
		log_shm=${PLELOG_ROOT}/$date/${time}_${server}${title}shmstat.log
		log_mem=${PLELOG_ROOT}/$date/${time}_${server}${title}memstat.log
		log_swap=${PLELOG_ROOT}/$date/${time}_${server}${title}swapstat.log
	fi

	[ x"$server" == x ] && server=$(cut -d_ -f2 <<< $log_mem)

	exit_if_file_not_exists $log_shm
	exit_if_file_not_exists $log_mem
}

#	============================================================================
#	MAIN
#	============================================================================
if [ $show_log_only == yes ]
then
	set_to_last_date
	show_formatted_logs
	exit 0
fi

test_if_cmd_exists gnuplot
if [ $? -ne 0 ]
then
	error "gnuplot n'est pas installé ou pas dans PATH."
	exit 1
fi

make_log_names

#	Lecture de l'heure de début des mesures
typeset -r	start_time=$(sed -n "2p" $log_shm | cut -d' ' -f1)

# Lecture de la seconde mesure (ligne 3 donc) pour déterminer le refresh rate.
typeset -r	second_time=$(sed -n "3p" $log_shm | cut -d' ' -f1)

# Fréquence de rafraîchissement :
debug "start_time  = $start_time"
debug "second_time = $second_time"
typeset		refresh_rate=$(compute \
				 "($(time_to_secs $second_time) - $(time_to_secs $start_time))*2")

# boxes lines linespoints points impulses histeps
# ok : points, histeps, linespoints
typeset -r with="linespoints pointinterval $(( (5*60) / refresh_rate ))"

typeset	-r	fmt_time="%H:%M:%S"

typeset plot_cmds=/tmp/memory.plot.$$
#https://www2.uni-hamburg.de/Wiss/FB/15/Sustainability/schneider/gnuplot/colors.htm

typeset -i line_to_skip=1

typeset graph_title=$title
[ "${graph_title%_}" == "global" ] && graph_title="Start at $time (Points interval : 5mn)"

typeset -r stats_info=${PLELOG_ROOT}/$date/stats_info.txt
if [ $loop == yes ]
then
	cmds="$(printf "pause $refresh_rate\nreread\nreplot\n")"
else
	cmds="pause -1"
fi

cat << EOS > $plot_cmds
set key autotitle columnhead
set grid
set datafile separator " "
set term qt title '${server%_} : ${graph_title}' size 944,512
set title '${server%_} : ${graph_title}'
set format x '$fmt_time'
set timefmt '$fmt_time'
set xdata time
set xlabel 'Time'
set xtic rotate by -45
set ylabel 'Mega bytes (Mb)'
#set label "Create Database Started" at "12:33:23",1 rotate
#set label "Create Database Finished" at "13:17:20",1 rotate
plot	\
	"$log_mem" using 1:2 title 'Mem Max'	with lines lt rgb "red",		\
	"$log_mem" using 1:3 title 'Mem Used'	with ${with} lt rgb "orange",	\
	"$log_shm" using 1:2 title 'SHM Max'	with lines lt rgb "brown",	\
	"$log_shm" using 1:3 title 'SHM Used'	with ${with} lt rgb "green",	\
	"$log_swap" using 1:3 title 'Swap Used'	with ${with} lt rgb "blue"
$cmds
EOS

line_separator
cat $plot_cmds
LN

line_separator
info "Refresh rate $(fmt_seconds $refresh_rate)"
LN

line_separator
info "Load file    $log_shm"
info "Load file    $log_mem"
info "Load file    $log_swap"
LN

line_separator
gnuplot $plot_cmds
info "gnuplot return $?"
exit 0
#rm -rf nohup.out >/dev/null 2>&1
#nohup gnuplot $plot_cmds &
#info "My pid is $!"
