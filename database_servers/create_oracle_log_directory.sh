#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME -db=name"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
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

#ple_enable_log -params $PARAMS

must_be_executed_on_server $client_hostname

exit_if_param_undef db	"$str_usage"

cfg_exists $db

typeset	-t	upper_db=$(to_upper $db)
typeset	-ri	max_nodes=$(cfg_max_nodes $db)

for (( i = 1; i <= $max_nodes; ++i ))
do
	line_separator
	cfg_load_node_info $db $i

	ORACLE_BASE=$(ssh oracle@$cfg_server_name '. .bash_profile && echo $ORACLE_BASE')
	exec_cmd "ssh -t oracle@$cfg_server_name \"[ ! -d $ORACLE_BASE/admin/$upper_db/log ] && mkdir \\$ORACLE_BASE/admin/$upper_db/log || true\""
	LN
	exec_cmd "ssh -t oracle@$cfg_server_name \"[ ! -L log ] && ln -s $ORACLE_BASE/admin/$upper_db/log log || true\""
	LN
	exec_cmd "ssh -t oracle@$cfg_server_name \"[ ! -L $upper_db ] && ln -s $ORACLE_BASE/admin/$upper_db $upper_db || true\""
	LN
done
