#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset	other_node=undef
while read node_name node_number
do
	if [ $node_name != $(hostname -s) ]
	then
		other_node=$node_name
		break
	fi
done<<<"$(olsnodes -n)"

tmux new -s Monitor							\; \
			split-window -h "ssh -t $other_node"  \; \
			selectp -t 0 

