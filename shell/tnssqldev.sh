#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

if [ x"$TNS_ADMIN" == x ]
then
	if [ ! -d ~/plescripts/tnsadmin ]
	then
		exec_cmd mkdir ~/plescripts/tnsadmin
		LN
	fi
	info "export TNS_ADMIN=~/plescripts/tnsadmin"
	export TNS_ADMIN=~/plescripts/tnsadmin
fi

must_be_executed_on_server $client_hostname

add_usage "-db=dbname"				"Database name."
add_usage "[-pdb=pdbname]"			"PDB name."
add_usage "[-server=auto]"			"Server name. auto read server name from cfg file."
add_usage "[-service=auto|name]"	"Service name."

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

#ple_enable_log -params $PARAMS

exit_if_param_undef db	"$str_usage"

cfg_exists $db

typeset	-ri max_nodes=$(cfg_max_nodes $db)

info "$db #$max_nodes nodes."
LN

if [ "$pdb" != undef ]
then
	case $service in
		auto)
			service=$(mk_java_service $pdb)
			stby_service=$(mk_java_stby_service $pdb)
			typeset -r stby_alias_name=$(to_upper ${db}_${pdb}_stby)
			;;
	esac
	typeset -r alias_name=$(to_upper ${db}_${pdb})
else
	case "$service" in
		auto)
			service=$db
			;;
	esac
	typeset -r alias_name=$(to_upper $db)
fi

typeset	dataguard=no
if [ "$server" == auto ]
then
	if [ $max_nodes -gt 1 ]
	then
		server=${db}-scan
	else
		cfg_load_node_info $db 1
		server=$cfg_server_name
		if [[ "$cfg_standby" != none ]]
		then
			info "Dataguard detected."
			if [[ "$pdb" == undef ]]
			then
				info "No dataguard cfg for cdb, only pdb."
				LN
			else
				dataguard=yes
				cfg_load_node_info $cfg_standby 1
				server="'$server $cfg_server_name'"
				info "server list : $server"
				LN
			fi
		fi
	fi
fi

info "Update $TNS_ADMIN/tnsnames.ora"
info "    alias   $alias_name"
info "    service $service"
info "    server  $server"
LN

exec_cmd ~/plescripts/db/delete_tns_alias.sh -tnsalias=$alias_name
LN

exec_cmd "~/plescripts/shell/gen_tns_alias.sh	-service=$service		\
												-server_list=$server	\
												-alias_name=$alias_name >> $TNS_ADMIN/tnsnames.ora"
LN

exec_cmd "sed -i 's/$alias_name =$/$alias_name = #${ME##*/}/' $TNS_ADMIN/tnsnames.ora"
LN

if [ $dataguard == yes ]
then
	info "Add alias RO on standby PDB"
	info "    alias   $stby_alias_name"
	info "    service $stby_service"
	info "    server  $server"
	LN

	exec_cmd ~/plescripts/db/delete_tns_alias.sh -tnsalias=$stby_alias_name
	LN

	exec_cmd "~/plescripts/shell/gen_tns_alias.sh	-service=$stby_service		\
													-server_list=$server	\
													-alias_name=$stby_alias_name >> $TNS_ADMIN/tnsnames.ora"
	LN

	exec_cmd "sed -i 's/$stby_alias_name =$/$stby_alias_name = #${ME##*/}/' $TNS_ADMIN/tnsnames.ora"
	LN
fi

if [ "$pdb" == undef ]
then
	info "For pdb add -pdb=pdbname"
	LN
fi
