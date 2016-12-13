#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-db=name]

IO d'un RAC 2 nœuds.
"

script_banner $ME $*

typeset	db=undef

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

[[ $db = undef ]] && [[ -v ID_DB ]] && db=$ID_DB
exit_if_param_undef db	"$str_usage"

cfg_exists $db

cfg_load_node_info $db 1
node1=$cfg_server_name

cfg_load_node_info $db 2
node2=$cfg_server_name

typeset -r session_name="$node1/$node2"
exec_cmd -ci tmux kill-session -t \"$session_name\"

info "$session_name"
set -x
tmux new -s "$session_name"	"ssh -t root@${node1} \~/plescripts/disk/iostat_on_bdd_disks.sh"	\; \
			split-window -h "ssh -t root@${node2} \~/plescripts/disk/iostat_on_bdd_disks.sh"
