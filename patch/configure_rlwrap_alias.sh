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

function config_server
{
	typeset -r server_name="$1"

	line_separator
	exec_cmd "scp ~/plescripts/oracle_preinstall/rlwrap.alias root@$server_name:~/"
	exec_cmd "ssh root@$server_name 'echo \". rlwrap.alias \" >> .bash_profile'"
	LN

	line_separator
	exec_cmd "scp ~/plescripts/oracle_preinstall/rlwrap.alias oracle@$server_name:~/"
	exec_cmd "ssh oracle@$server_name 'sed -i \"/Execute asmcmd/d\" profile.oracle'"
	exec_cmd "ssh oracle@$server_name 'sed -i \"/alias asmcmd/d\" profile.oracle'"
	exec_cmd "ssh oracle@$server_name 'echo \". rlwrap.alias\" >> profile.oracle'"
	LN

	line_separator
	exec_cmd "scp ~/plescripts/oracle_preinstall/rlwrap.alias grid@$server_name:~/"
	exec_cmd "ssh grid@$server_name 'echo ". rlwrap.alias " >> profile.grid'"
	LN
}

typeset -r cfg_path=~/plescripts/database_servers/$db
exit_if_dir_not_exists $cfg_path
for node_file in $cfg_path/node*
do
	server_name=$(cat $node_file | cut -d: -f2)
	config_server $server_name
done
