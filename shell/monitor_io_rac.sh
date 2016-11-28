#/bin/bash

. ~/plescripts/plelib.sh
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

xterm $xterm_static_options -geometry ${width_rac}x${height}$top_left \
		-e "tmux_io_rac.sh" &
