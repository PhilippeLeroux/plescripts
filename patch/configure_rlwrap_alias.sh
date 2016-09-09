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
typeset server=undef

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

		-server=*)
			server=${1##*=}
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

[[ $db == undef && $server == undef && -v ID_DB ]] && db=$ID_DB
[[ $db == undef && $server == undef ]] && error "-db and -server undef" && info "$str_usage" && exit 1
[[ $db != undef && $server != undef ]] && error "-db and -server defined" && info "$str_usage" && exit 1

function config_server
{
	typeset -r server_name="$1"

	line_separator
	exec_cmd "scp ~/plescripts/oracle_preinstall/rlwrap.alias root@$server_name:~/"
	exec_cmd "ssh root@$server_name 'sed -i \"/.*rlwrap.alias/d\" .bash_profile'"
	exec_cmd "ssh root@$server_name 'echo \". rlwrap.alias \" >> .bash_profile'"
	LN

	line_separator
	exec_cmd "scp ~/plescripts/oracle_preinstall/rlwrap.alias oracle@$server_name:~/"
	exec_cmd "ssh oracle@$server_name 'sed -i \"/alias asmcmd/d\" profile.oracle'"
	exec_cmd "ssh oracle@$server_name 'sed -i \"/.*rlwrap.alias/d\" profile.oracle'"
	exec_cmd "ssh oracle@$server_name 'echo \". rlwrap.alias\" >> profile.oracle'"
	LN

	line_separator
	exec_cmd "scp ~/plescripts/oracle_preinstall/rlwrap.alias grid@$server_name:~/"
	exec_cmd "ssh grid@$server_name 'sed -i \"/.*rlwrap.alias/d\" profile.grid'"
	exec_cmd "ssh grid@$server_name 'echo ". rlwrap.alias " >> profile.grid'"
	LN
}

if [ $server != undef ]
then
	config_server  $server
else
	typeset -r cfg_path=~/plescripts/database_servers/$db
	exit_if_dir_not_exists $cfg_path
	for node_file in $cfg_path/node*
	do
		server_name=$(cat $node_file | cut -d: -f2)
		config_server $server_name
	done
fi
