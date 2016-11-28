#/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
EXEC_CMD_ACTION=EXEC

#	Dimensiont du terminal
typeset -r width_rac=174
typeset -r height=48
typeset -r width_single=$(( $width_rac / 2 ))

#	Positions du terminal
typeset -r top_right=+1024+0
typeset -r bottom_right=+1024+550

typeset -r top_left=+0+0
typeset -r bottom_left=+0+550

#	Font du terminal
typeset -r xterm_static_options="-fa 'Monospace' -fs 14 +sb -rv"

db=$1

if [ $# -eq 0 ]
then
	[ -f /tmp/id_db ] && ID_DB=$(cat /tmp/id_db)
	[ -z $ID_DB ] && error "Erreur id_db attendu." && exit 1
	db=$ID_DB

	wait_server
fi

cfg_exist $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

if [ $max_nodes -eq 2 ]
then
	xterm $xterm_static_options -geometry ${width_rac}x${height}$top_left \
		-e "tmux_monitor_server.sh -node1=srv${db}01 -node2=srv${db}02" &
else
	xterm $xterm_static_options -geometry ${width_rac}x${height}$top_right \
		-e "tmux_monitor_server.sh -db=$db -node1=srv${db}01" &
fi
