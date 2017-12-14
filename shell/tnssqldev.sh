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

typeset -r str_usage=\
"Usage : $ME
$(print_usage)
"

typeset db=undef
typeset pdb=undef

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

		-pdb=*)
			pdb=${1##*=}
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

# Add script name in comment.
# $1 alias name
function add_comment_to_alias_name
{
	exec_cmd "sed -i 's/$1 =$/$1 = #${ME##*/}/' $TNS_ADMIN/tnsnames.ora"
	LN
}

cfg_exists $db

typeset	-ri max_nodes=$(cfg_max_nodes $db)

cfg_load_node_info $db 1

info -n "$db #$max_nodes nodes"
if [ $cfg_dataguard == yes ]
then
	info -f " : dataguard."
elif [ $cfg_db_type == rac ]
then
	info -f " : RAC."
else
	info -f "."
fi
LN

typeset	-a	alias_name_list
typeset	-a	service_list
typeset	-a	server_list

if [ $pdb == undef ]
then
	if [ $cfg_dataguard == yes ]
	then
		alias_name_list=( $(to_upper $db)01 $(to_upper $db)02 )
		service_list=( ${db}01 ${db}02 )
	else
		alias_name_list=( $(to_upper $db) )
		service_list=( $db )
	fi
else
	typeset -r stby_service=$(mk_java_stby_service $pdb)
	typeset -r stby_alias_name=$(to_upper ${db}_${pdb}_stby)

	alias_name_list=( $(to_upper ${db}_${pdb}) )
	service_list=( $(mk_java_service $pdb) )
fi

if [ $cfg_db_type == rac ]
then
	server_list=( ${db}-scan )
else
	cfg_load_node_info $db 1
	server_list=( $cfg_server_name )
	if [ $cfg_dataguard == yes ]
	then
		cfg_load_node_info $db 2
		server_list+=( $cfg_server_name )
	fi
fi

info "Update $TNS_ADMIN/tnsnames.ora"
LN

if [ $pdb == undef ]
then
	info "Add alias for CDB $db"
	info "    alias   ${alias_name_list[*]}"
	info "    service ${service_list[*]}"
	info "    server  ${server_list[*]}"
	LN

	for (( i = 0; i < ${#alias_name_list[*]}; ++i ))
	do
		alias_name=${alias_name_list[i]}
		service=${service_list[i]}
		server=${server_list[i]}

		exec_cmd ~/plescripts/db/delete_tns_alias.sh -tnsalias=$alias_name

		exec_cmd "~/plescripts/db/gen_tns_alias.sh			\
									-service=$service		\
									-server_list=$server	\
									-alias_name=$alias_name >> $TNS_ADMIN/tnsnames.ora"
		LN

		add_comment_to_alias_name $alias_name
	done

	info "For pdb add -pdb=pdbname"
	LN
else
	alias_name=${alias_name_list[0]}
	service=${service_list[0]}

	info "Add alias RW for pdb : $pdb@$db"
	info "    alias   $alias_name"
	info "    service $service"
	info "    server  ${server_list[*]}"
	LN

	exec_cmd ~/plescripts/db/delete_tns_alias.sh -tnsalias=$alias_name

	exec_cmd "~/plescripts/db/gen_tns_alias.sh					\
							-service=$service					\
							-server_list=\"${server_list[*]}\"	\
							-alias_name=$alias_name >> $TNS_ADMIN/tnsnames.ora"
	LN

	add_comment_to_alias_name $alias_name
fi

if [[ $cfg_dataguard == yes && $pdb != undef ]]
then
	info "Add alias RO for standby pdb $pdb@$db"
	info "    alias   $stby_alias_name"
	info "    service $stby_service"
	info "    server  ${server_list[*]}"
	LN

	exec_cmd ~/plescripts/db/delete_tns_alias.sh -tnsalias=$stby_alias_name

	exec_cmd "~/plescripts/db/gen_tns_alias.sh				\
						-service=$stby_service				\
						-server_list=\"${server_list[*]}\"	\
						-alias_name=$stby_alias_name >> $TNS_ADMIN/tnsnames.ora"
	LN

	add_comment_to_alias_name $alias_name
fi
