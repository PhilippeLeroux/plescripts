#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "Running : $ME $*"

typeset db=undef

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

typeset -r cfg_path=~/plescripts/database_servers/$db
exit_if_dir_not_exists $cfg_path

for node_file in $cfg_path/node*
do
	server=$(cut -d: -f2 < $node_file)
	exec_cmd "ssh root@${server} \
			\". ./.bash_profile; nohup plescripts/stats/memstats.sh -title=global >/tmp/log.txt 2>&1 </dev/null &\""
	LN
done
