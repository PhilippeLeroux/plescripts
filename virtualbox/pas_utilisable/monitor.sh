#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

line_separator
typeset input=/tmp/metrics_srvdonald01.txt
typeset output=/tmp/col_metrics_srvdonald01.txt
exec_cmd ./metrics_convert_row_to_col.sh -i=$input -o=$output
typeset -r metrics_server_01=$output
LN

line_separator
input=/tmp/metrics_srvdonald02.txt
output=/tmp/col_metrics_srvdonald02.txt
exec_cmd ./metrics_convert_row_to_col.sh -i=$input -o=$output
typeset -r metrics_server_02=$output
LN

typeset -r network_script=/tmp/monitor.network.script
typeset -r cpu_script=/tmp/monitor.cpu.script
typeset -r disk_script=/tmp/monitor.disk.script

#	Metrics header :
# TT NAME CpuUser% CpuKernel% RAMUsed DiskUsed Rate/Rx Rate/Tx
# 1	 2		3		4			5		6		7		8

# boxes lines linespoints points impulses histeps
# ok : points, histeps
typeset -r with=impulses

cat << EOS > $network_script
set grid
set datafile separator " "
set term wxt title 'srvdonald02 Network'
set title 'srvdonald02 Network'
set xdata time
set xlabel 'Time'
set format x '%H:%M:%S'
set timefmt '%H:%M:%S'
#set xtic rotate by 45 
set ylabel 'Kb/s"
plot	\
	'$metrics_server_01' using 1:(\$7/8/1024) title '01 Rx' with ${with} lt rgb "red",	\
	'$metrics_server_01' using 1:(\$8/8/1024) title '01 Tx' with ${with} lt rgb "blue",	\
	'$metrics_server_02' using 1:(\$7/8/1024) title '02 Rx' with ${with} lt rgb "green",\
	'$metrics_server_02' using 1:(\$8/8/1024) title '02 Tx' with ${with} lt rgb "yellow"
#pause 60
#reread
#replot
EOS

cat << EOS > $cpu_script
set grid
set datafile separator " "
set term wxt title 'Donald CPU'
set title 'Donald CPU'
set xdata time
set xlabel 'Time'
set format x '%H:%M:%S'
set timefmt '%H:%M:%S'
#set xtic rotate by 45 
set ylabel '%CPU'
plot	\
	'$metrics_server_01' using 1:3 title '01 User'		with ${with} lt rgb "red",		\
	'$metrics_server_01' using 1:4 title '01 Kernel'	with ${with} lt rgb "blue",		\
	'$metrics_server_02' using 1:3 title '02 User'	 	with ${with} lt rgb "green",	\
	'$metrics_server_02' using 1:4 title '02 Kernel'	with ${with} lt rgb "yellow"
#pause 60
#reread
#replot
EOS

cat << EOS > $disk_script
set grid
set datafile separator " "
set term wxt title 'srvdonald02 disk'
set title 'srvdonald02 disk'
set xdata time
set xlabel 'Time'
set format x '%H:%M:%S'
set timefmt '%H:%M:%S'
#set xtic rotate by 45 
set ylabel 'Disk used"
plot	\
	'$metrics_server_01' using 1:6 title 'Used' 	with ${with} lt rgb "red",	\
	'$metrics_server_02' using 1:6 title 'Used' 	with ${with} lt rgb "green"
#pause 60
#reread
#replot
EOS

line_separator
gnuplot --persist $network_script
LN

line_separator
gnuplot --persist $cpu_script
LN
#gnuplot --persist $disk_script
