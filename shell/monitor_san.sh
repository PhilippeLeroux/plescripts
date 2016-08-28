#/bin/bash

typeset -r width=85
typeset -r height=40

typeset -r top_right=+1024+0
typeset -r bottom_right=+1024+550

typeset -r top_left=+0+0
typeset -r bottom_left=+0+550

[ -f /tmp/id_db ] && db=$(cat /tmp/id_db)

#xterm -fa 'Monospace' -fs 14 -geometry ${width}x22$top_left -rv -e "ssh root@mydns vmstat 2" &
#xterm -fa 'Monospace' -fs 14 -geometry ${width}x22$bottom_left -rv -e "ssh -t root@mydns top" &
if [ x"$db" != x ]
then
	xterm -fa 'Monospace' -fs 14 -geometry ${width}x${height}$top_left -rv -e "ssh -t root@K2 \"~/plescripts/san/dbiostat.sh -db=$db\"" &
fi
