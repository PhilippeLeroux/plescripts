#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
		-title=<str>
		[-date=<YYYY-MM-DD>] not set, search last date.
		[-time=<HHhMM>]      not set, search last time.
		[-server=<name>]     can be omitted with only one server.
		[-show]              show log files.

Display files produced by memstats.sh with gnuplot"

typeset date=undef
typeset time=undef
typeset server=""
typeset title=""
typeset show=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

		-show)
			show=yes
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
	[ $date == undef ] && set_to_last_date

	if [ $time == undef ]
	then
		last_log_file=$(ls -rt ${PLELOG_ROOT}/$date/*${server}${title}shmstat.log 2>/dev/null)
		[ x"$last_log_file" = x ] && error "File not found in ${PLELOG_ROOT}/$date" && exit 1

		time=${last_log_file##*/}
		time=${time%%_*}
		info "set time to $time"
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
if [ $show == yes ]
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

# boxes lines linespoints points impulses histeps
# ok : points, histeps
typeset -r with=histeps

typeset	-r	fmt_time="%M:%S"

#	Lecture de l'heure de début des mesures
typeset -r	start_time=$(sed -n "2p" $log_shm | cut -d' ' -f1)

# Lecture de la seconde mesure (ligne 3 donc) pour déterminer le refresh rate.
typeset -r	second_time=$(sed -n "3p" $log_shm | cut -d' ' -f1)

# Fréquence de rafraîchissement :
typeset		refresh_rate=$(compute "($(time_to_secs $second_time) - $(time_to_secs $start_time))*2")

info "Load file    $log_shm"
info "Load file    $log_mem"
info "Load file    $log_swap"
info "Refresh rate $(fmt_seconds $refresh_rate)"

typeset plot_cmds=/tmp/memory.plot.$$
#https://www2.uni-hamburg.de/Wiss/FB/15/Sustainability/schneider/gnuplot/colors.htm

typeset graph_title=$title
[ $graph_title == global_ ] && graph_title="Start at $time"

cat << EOS > $plot_cmds
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
plot	\
	"$log_mem" using 1:2 title 'Mem Total'  with ${with} lt rgb "red",		\
	"$log_mem" using 1:3 title 'Mem Used'	with ${with} lt rgb "orange",	\
	"$log_shm" using 1:2 title 'SHM Total'  with ${with} lt rgb "brown",	\
	"$log_shm" using 1:3 title 'SHM Used'	with ${with} lt rgb "green",	\
	"$log_swap" using 1:3 title 'Swap Used'	with ${with} lt rgb "blue"
pause 60
reread
replot
EOS

#"$log_mem $log_shm"         using 1:(\$1+\$4) title 'RAM Used'	with ${with} lt rgb "yellow",	\
rm -rf nohup.out >/dev/null 2>&1
gnuplot $plot_cmds
info "My pid is $!"
