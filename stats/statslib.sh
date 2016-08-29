# vim: ts=4:sw=4

typeset -r PLESTATS_PATH=$PLELOG_PATH/stats

if [ ! -f $PLESTATS_PATH ]
then
	mkdir $PLESTATS_PATH >/dev/null 2>&1
	chmod ug=rwx,o=rx $PLESTATS_PATH >/dev/null 2>&1
fi

#	Permet d'indiquer les heures d'arrêt/démarrage d'un composant.
#	$1	start|stop
#	$2	nom du composant.
#	Exemple
#		stats_tt start grid
#		stats_tt stop grid
function stats_tt
{
	typeset -r action=$1
	typeset -r id=$2

	case $action in
		start)
			echo "start $id $(date +"%H:%M:%S")" >> $PLESTATS_PATH/stats_info.txt
			;;

		stop)
			echo "stop $id $(date +"%H:%M:%S")" >> $PLESTATS_PATH/stats_info.txt
			;;

		*)
			error "$0 action '$action' invalid."
			exit 1
			;;
	esac
}
