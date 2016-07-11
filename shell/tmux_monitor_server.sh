#!/bin/ksh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -node1=<str> [-node2=<str>]

Monitor un server Oracle standalone ou 2 nœuds d'un RAC via tmux.
Le script est prévu pour être exécuté depuis le poste client.
"

info "$ME $@"

typeset	db=undef
typeset	node1=undef
typeset	node2=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-node1=*)
			node1=${1##*=}
			shift
			;;

		-node2=*)
			node2=${1##*=}
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

exit_if_param_undef node1 "$str_usage"

if [ $node2 != undef ]
then
typeset -r	session_name="Left $node1 / Right $node2"
exec_cmd -ci tmux kill-session -t \"$session_name\"

tmux new -s "$session_name"	"ssh root@${node1} vmstat 2"				\; \
							split-window -h "ssh root@${node2} vmstat 2" \; \
							split-window -v "ssh -t root@${node2} top" \; \
							selectp -t 0 \; \
							split-window -v "ssh -t root@${node1} top"
else
typeset -r session_name="$node1"
exec_cmd -ci tmux kill-session -t \"$session_name\"

tmux new -s "$session_name"	ssh -t root@K2 "~/plescripts/san/dbiostat.sh -db=$db"	\;\
							split-window -h "ssh root@${node1} vmstat 2"			\;\
							split-window -v "ssh -t root@${node1} top"
fi
