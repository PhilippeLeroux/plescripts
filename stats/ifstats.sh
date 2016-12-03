#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
. ~/plescripts/stats/statslib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-title=<str>     titre du jeu de statistiques.
	-ifname=<str>    nom de l'interface.
	[-stop]          stop la capture des statistiques.
	[-count=<#>]     nombre maximal de mesures à prendre, par défaut pas de limite.
	[-pause=1]       pause en secondes entre 2 mesures.

	Statistiques sur le débit des cartes réseaux en Kb.
	Utiliser ifplot.sh pour affichage graphique de la sortie.
"


script_banner $ME $*

typeset -i	max_count=0
typeset -i	pause_of_secs=1
typeset		action=start
typeset		title=undef
typeset		ifname=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-ifname=*)
			ifname=${1##*=}
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
exit_if_param_undef ifname "$str_usage"

typeset	-r	if_file=$PLESTATS_PATH/$(date +"%Hh%M")_$(hostname -s)_${title}${ifname}.log

typeset	-i prev_rx_b=-1
typeset	-i prev_rx_packets
typeset	-i prev_tx_b
typeset	-i prev_tx_packets

function write_headers
{
	echo "$(date +"%Y:%m:%d") rx_kb rx_packets tx_kb tx_packets" > $if_file
	chmod ug=rw $if_file
	chgrp users $if_file
}

function write_stats
{
	if [ $pause_of_secs -lt 60 ]
	then
		typeset -r timestamp=$(date +"%H:%M:%S")
	else
		typeset -r timestamp=$(date +"%H:%M")
	fi

	typeset -i if_num=0
	read iface_name rx_b rx_packets f1 f2 f3 f4 f5 f6 tx_b tx_packets rem<<<"$(cat /proc/net/dev | grep -E "$ifname" | tr -s [:space:])"
	if [ ${prev_rx_b} -ne -1 ]
	then	# After first line
		echo "$timestamp $(( (rx_b - prev_rx_b) / 1024 )) $(( rx_packets - prev_rx_packets )) $(( (tx_b - prev_tx_b) / 1024 )) $(( tx_packets - prev_tx_packets ))" >> $if_file
	fi
	prev_rx_b=$rx_b
	prev_rx_packets=$rx_packets
	prev_tx_b=$tx_b
	prev_tx_packets=$tx_packets
}

function remove_pid_file
{
	rm $pid_file
}

function get_pid_file_suffix
{
	echo "$(hostname -s)_${title}running_${ifname}.pid"
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
		main
		;;

	*)
		error "action = '$action'"
		exit 1
		;;
esac
