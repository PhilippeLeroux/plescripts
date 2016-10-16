#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

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
exit_if_dir_not_exist $cfg_path
for node_file in $cfg_path/node*
do
	server_name=$(cat $node_file | cut -d: -f2)
	exec_cmd "ssh  oracle@${server_name} '. .bash_profile; cp ~/plescripts/oracle_preinstall/glogin.sql \$ORACLE_HOME/sqlplus/admin/glogin.sql'"
	LN
done
