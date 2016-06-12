#/bin/sh

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

#	Dimensiont du terminal
typeset -r width=85
typeset -r height=22

#	Positions du terminal
typeset -r top_right=+1024+0
typeset -r bottom_right=+1024+550

typeset -r top_left=+0+0
typeset -r bottom_left=+0+550

#	Font du terminal
typeset -r xterm_static_options="-fa 'Monospace' -fs 14"

db=$1

[ $db = undef ] && exit 0

if [ $# -eq 0 ]
then
	[ -f /tmp/id_db ] && ID_DB=$(cat /tmp/id_db)
	[ -z $ID_DB ] && error "Erreur id_db attendu." && exit 1
	db=$ID_DB
fi

typeset -r dir_files=~/plescripts/database_servers/$db
[ ! -d $dir_files ] && error "$dir_files not exists." && exit 1

function is_running # $1 server name
{
	ps -ef | grep xterm | grep -v grep | cut -d'@' -f2 | cut -d' ' -f1 | grep $1 2>&1 >/dev/null
	echo $?
}

count_nodes=$(ls -1 $dir_files/node* | wc -l)

if [ $count_nodes -eq 2 ]
then
	if [ $(is_running srv${db}01) -ne 0 ]
	then
		xterm $xterm_static_options -geometry ${width}x${height}$top_left -rv -e "ssh root@srv${db}01 vmstat 2" &
		xterm $xterm_static_options -geometry ${width}x${height}$bottom_left -rv -e "ssh -t root@srv${db}01 top" &
	fi

	if [ $(is_running srv${db}02) -ne 0 ]
	then
		xterm $xterm_static_options -geometry ${width}x${height}$top_right -rv -e "ssh root@srv${db}02 vmstat 2" &
		xterm $xterm_static_options -geometry ${width}x${height}$bottom_right -rv -e "ssh -t root@srv${db}02 top" &
	fi
else
	if [ $(is_running srv${db}01) -ne 0 ]
	then
		xterm $xterm_static_options -geometry ${width}x${height}$top_right -rv -e "ssh root@srv${db}01 vmstat 2" &
		xterm $xterm_static_options -geometry ${width}x${height}$bottom_right -rv -e "ssh -t root@srv${db}01 top" &
	fi
fi

