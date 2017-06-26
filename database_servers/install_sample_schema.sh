#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset db=undef

typeset -r str_usage=\
"Usage : $ME
	-db=name
"

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

script_banner $ME $*

must_be_executed_on_server $client_hostname

exit_if_param_undef db	"$str_usage"

cfg_exists $db

typeset -ri	max_nodes=$(cfg_max_nodes $db)

typeset -r	url=https://github.com/oracle/db-sample-schemas/archive/v${oracle_release}.tar.gz

typeset -r	archive_dir="$HOME/plescripts/tmp"
typeset -r	archive="$archive_dir/v${oracle_release}.tar.gz"

if [ ! -f "$archive" ]
then
	fake_exec_cmd cd $archive_dir
	cd $archive_dir || exit 1
	LN

	exec_cmd wget $url
	LN
fi

for (( inode=1; inode <= max_nodes; ++inode ))
do
	cfg_load_node_info $db $inode
	exec_cmd "ssh oracle@${cfg_server_name} 'rm -rf db-sample-schemas-${oracle_release}'"
	LN
	exec_cmd "ssh oracle@${cfg_server_name} 'gzip -dc plescripts/tmp/v${oracle_release}.tar.gz | tar xf - '"
	LN
	if [ $oracle_release == 12.1.0.2 ]
	then # Bug Oracle avec sqlloader
		exec_cmd "ssh oracle@${cfg_server_name} 'mkdir db-sample-schemas-${oracle_release}/logs'"
		LN
	fi
done
