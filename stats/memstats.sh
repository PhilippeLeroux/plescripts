#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -title=<str> [-count=<#>] [-pause=1]
	Statistiques sur la consommation mémoire.
	Utiliser memplot.sh pour affichage graphique de la sortie."

info "Running : $ME $*"

typeset -i	max_count=0
typeset -i	pause_of_secs=1
typeset		action=normal
typeset		title=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-count=*)
			max_count=${1##*=}
			shift
			;;

		-pause=*)
			pause_of_secs=${1##*=}
			shift
			;;

		-title=*)
			title=${1##*=}_
			shift
			;;

		-kill)
			action=kill
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

exit_if_param_undef title "$str_usage"

typeset -r mem_file=$PLELOG_PATH/$(date +"%Hh%M")_$(hostname -s)_${title}memstat.log
typeset -r swap_file=$PLELOG_PATH/$(date +"%Hh%M")_$(hostname -s)_${title}swapstat.log
typeset -r shm_file=$PLELOG_PATH/$(date +"%Hh%M")_$(hostname -s)_${title}shmstat.log

function write_headers
{
	echo "$(date +"%Y:%m:%d") total used free shared buffer cached" > $mem_file
	echo "$(date +"%Y:%m:%d") total used free" > $swap_file
	echo "$(date +"%Y:%m:%d") total used free Used%" > $shm_file

	#	Obligatoire avec vboxsf
	chmod ug=rw $mem_file $swap_file $shm_file
}

function write_stats
{
	if [ $pause_of_secs -lt 60 ]
	then
		typeset -r timestamp=$(date +"%H:%M:%S")
	else
		typeset -r timestamp=$(date +"%H:%M")
	fi

	typeset -i iline=0
	while read label total used free shared buffer cached
	do
		iline=iline+1
		case $iline in
			2)	echo "$timestamp $total $used $free $shared $buffer $catched" >> $mem_file
				;;

			3)	echo "$timestamp $total $used $free $shared" >> $swap_file
				;;
		esac
	done<<<"$(free -m)"

	iline=0
	while read fs total used available pct_use mount_point
	do
		iline=iline+1
		case $iline in
			2)	echo "$timestamp $total $used $available $pct_use" >> $shm_file
				;;
		esac
	done<<<"$(df -m /dev/shm)"
}

function remove_fork_pid_file
{
	rm $fork_pid_file
}

function get_fork_pid_suffix
{
	echo "$(hostname -s)_${title}running.pid"
}

function main
{
	write_headers

	typeset -i count=0
	while [ 0 -eq 0 ]	# forever
	do
		count=count+1
		write_stats
		[ $max_count -ne 0 ] && [ $count -eq $max_count ] && break
		sleep $pause_of_secs
	done
}

case $action in
	kill)
		[ x"$title" = x ] && error "use -title with -kill" && exit 1
		fork_pid_file=$(find /tmp/*_$(get_fork_pid_suffix) 2>/dev/null)
		if [ $? -ne 0 ] || [ x"$fork_pid_file" = x ]
		then
			error "no process found with title ${title%_}"
			exit
		fi

		pid_to_stop=$(cat $fork_pid_file)
		info -n "Stop $0 $pid_to_stop : "
		kill -15 $pid_to_stop >/dev/null 2>&1
		[ $? -eq 0 ] && info -f "[$OK]" || info -f "[$KO]"
		;;

	normal)
		if [ ! -t 1 ] && [ ! -t 2 ]
		then	# Si 1 et 2 sont fermés suppose lancement en background
			fork_pid_file=/tmp/$(date +"%Hh%M")_$(get_fork_pid_suffix)
			echo "$$" > $fork_pid_file
			trap remove_fork_pid_file EXIT
		fi
		main
		;;

	*)
		error "action = '$action'"
		exit 1
		;;
esac
