#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

. ~/plescripts/stats/statslib.sh

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	-title=<str>     titre du jeu de statistiques.
	[-stop]          stop la capture des statistiques.
	[-count=<#>]     nombre maximal de mesures à prendre, par défaut pas de limite.
	[-pause=1]       pause en secondes entre 2 mesures.

	Statistiques sur la consommation mémoire.
	Utiliser memplot.sh pour affichage graphique de la sortie."

typeset -i	max_count=0
typeset -i	pause_of_secs=1
typeset		action=start
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

		-stop)
			action=stop
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

#	Il faut utiliser un TT sinon la dernière log créée peut être dans la minute suivante.
typeset	TT=$(date +"%Hh%M")
typeset -r mem_file=$PLESTATS_PATH/${TT}_$(hostname -s)_${title}memstat.log
typeset -r swap_file=$PLESTATS_PATH/${TT}_$(hostname -s)_${title}swapstat.log
typeset -r shm_file=$PLESTATS_PATH/${TT}_$(hostname -s)_${title}shmstat.log
unset TT

function write_headers
{
	typeset	-r TT=$(date +"%Y:%m:%d")
	echo "$TT total used free shared buffer cached" > $mem_file
	echo "$TT total used free" > $swap_file
	echo "$TT +"%Y:%m:%d") total used free Used%" > $shm_file

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

function remove_pid_file
{
	rm $pid_file
}

function get_pid_file_suffix
{
	echo "$(hostname -s)_${title}running_mem.pid"
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
	stop)
		[ x"$title" == x ] && error "use -title with -stop" && exit 1
		pid_file=$(find /var/run/*_$(get_pid_file_suffix) 2>/dev/null)
		if [ $? -ne 0 ] || [ x"$pid_file" == x ]
		then
			error "no process found with title ${title%_}"
			exit 1
		fi

		pid_to_stop=$(cat $pid_file)
		info "Send signal SIGTERM to $pid_to_stop"
		kill -15 $pid_to_stop >/dev/null 2>&1
		sleep 2	# Laisse le temps au script de se terminer.
		if [ -f $pid_file ]
		then
			error "Failed to stop $pid_to_stop"
			exit 1
		else
			info "$pid_to_stop stopped."
			exit 0
		fi
		;;

	start)
		pid_file=/var/run/$(date +"%Hh%M")_$(get_pid_file_suffix)
		echo "$$" > $pid_file
		trap remove_pid_file EXIT
		sleep 60
		main
		;;

	*)
		error "action = '$action'"
		exit 1
		;;
esac
