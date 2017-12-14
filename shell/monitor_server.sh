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

[ -t 0 ] && exec_from=terminal || exec_from=gui

[ -f /tmp/id_db ] && ID_DB=$(cat /tmp/id_db)
if [ -z $ID_DB ]
then
	if [ $exec_from == terminal ]
	then
		error "Erreur id_db attendu."
		LN
	else
		notify "Error ID_DB undef."
		LN
	fi
	exit 1
fi

db=$ID_DB

[ $exec_from == gui ] && notify "Wait server : $db" || true
wait_server
[[ $? -ne 0 && $exec_from == gui ]] && notify "Wait server $db failed." || true

if [ $exec_from == terminal ]
then
	cfg_exists $db
else
	cfg_exists $db use_return_code
	if [ $? -ne 0 ]
	then
		notify "ID '$db' not exists."
		exit 1
	fi
fi

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

cfg_load_node_info $db 1
if [ $cfg_db_type == rac ]
then
	xterm $xterm_static_options -geometry ${width_rac}x${height}$top_left \
		-e "tmux_monitor_server.sh -node1=srv${db}01 -node2=srv${db}02" &
else
	xterm $xterm_static_options -geometry ${width_rac}x${height}$top_right \
		-e "tmux_monitor_server.sh -node1=srv${db}01" &
	if [ $cfg_dataguard == yes ]
	then
	xterm $xterm_static_options -geometry ${width_rac}x${height}$top_right \
		-e "tmux_monitor_server.sh -node1=srv${db}02" &
	fi
fi
