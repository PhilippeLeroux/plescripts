#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r sqldeveloper_path=$HOME/sqldeveloper
if [ ! -v TNS_ADMIN ]
then
	if [ -d $sqldeveloper_path ]
	then
		export TNS_ADMIN=$sqldeveloper_path
	else
		error "TNS_ADMIN not defined and $sqldeveloper_path not exists."
		exit 1
	fi
fi

must_be_executed_on_server $client_hostname

add_usage "-db=dbname"			"Database name."
add_usage "[-pdb=pdbname]"		"PDB name."
add_usage "[-server=auto]"		"Server name"
add_usage "[-service=auto]"		"Service name."

typeset -r str_usage=\
"Usage : $ME
$(print_usage)

Add alias to $TNS_ADMIN/tnsnames.ora :
	\$dbname or \${dbname}_\${pdbname}
"

typeset db=undef
typeset pdb=undef
typeset service=auto
typeset server=auto

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-server=*)
			server=${1##*=}
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-service=*)
			service=${1##*=}
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

#ple_enable_log

script_banner $ME $*

[[ $db == undef && x"$ID_DB" != x ]] && db=$ID_DB || true
exit_if_param_undef db	"$str_usage"

cfg_exists $db

typeset	-ri max_nodes=$(cfg_max_nodes $db)

info "$db #$max_nodes nodes."
LN

typeset alias_name=${db}

if [ "$pdb" != undef ]
then
	alias_name=$(to_upper ${db}_${pdb})
	[ "$service" == auto ] && service=$(mk_oci_service $pdb) || true
else
	alias_name=$(to_upper ${db})
	[ "$service" == auto ] && service=$db || true
fi

if [ "$server" == auto ]
then
	if [ $max_nodes -gt 1 ]
	then
		server=${db}-scan
	else
		cfg_load_node_info $db 1
		server=$cfg_server_name
	fi
fi

info "Update $TNS_ADMIN/tnsnames.ora"
info "    alias   $alias_name"
info "    service $service"
info "    server  $server"
LN

exec_cmd ~/plescripts/db/add_tns_alias.sh	-service=$service	\
											-host_name=$server	\
											-tnsalias=$alias_name
LN

exec_cmd "sed -i 's/$alias_name =$/$alias_name = #${ME##*/}/' $TNS_ADMIN/tnsnames.ora"
LN

if [ "$pdb" == undef ]
then
	info "For pdb add -pdb=pdbname"
	LN
fi
