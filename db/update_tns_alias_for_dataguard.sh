#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage :
$ME
	-pdb=name  PDB name or all to create alias on all pdbs
	[-db=name] Only if -pdb=all
	-dataguard_list=\"server1 server2\" except primary server.

Add or update allias for dataguard :
	$(mk_oci_service [pdb_name])
	$(mk_oci_stby_service [pdb_name])
	$(mk_java_service [pdb_name])
	$(mk_java_stby_service [pdb_name])

tnsname.ora is updated on all servers.
"

typeset db=undef
typeset pdb=undef
typeset dataguard_list=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_upper ${1##*=})
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-dataguard_list=*)
			dataguard_list=${1##*=}
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

exit_if_param_undef pdb				"$str_usage"
exit_if_param_undef dataguard_list	"$str_usage"

if [ "$pdb" == all ]
then
	exit_if_param_undef db	"$str_usage"
fi

must_be_user oracle

# $1 alias
function add_or_update_tns_alias
{
	typeset -r alias="$1"
	info "Add or update alias $alias"
	exec_cmd "~/plescripts/db/add_tns_alias.sh					\
								-service=$alias					\
								-host_name=$hostn				\
								-dataguard_list=\"$dataguard_list\""

	for server_name in $dataguard_list
	do
		exec_cmd "ssh $server_name '. .bash_profile &&					\
									~/plescripts/db/add_tns_alias.sh	\
										-service=$alias					\
										-host_name=$hostn				\
										-dataguard_list=\"$dataguard_list\"'"
	done
}

# $1 pdb
function add_or_update_tns_alias_for_pdb
{
	line_separator
	add_or_update_tns_alias $(mk_oci_service $1)
	add_or_update_tns_alias $(mk_oci_stby_service $1)
	add_or_update_tns_alias $(mk_java_service $1)
	add_or_update_tns_alias $(mk_java_stby_service $1)
}

function add_or_update_tns_alias_for_all_pdbs
{
	info "Database $db read all PDBs."
	while read pdb
	do
		[ x"$pdb" == x ] && continue

		add_or_update_tns_alias_for_pdb $pdb

	done<<<"$(get_sql_read_pdbs_rw $ORACLE_SID)"
}

typeset	-r	tnsnames_file=$TNS_ADMIN/tnsnames.ora

if [ ! -d "$TNS_ADMIN" ]
then
	error "Directory TNS_ADMIN='$TNS_ADMIN' not exist."
	exit 1
fi

typeset -r hostn=$(hostname -s)
dataguard_list=${dataguard_list/$hostn/}

if [ "$pdb" == all ]
then
	add_or_update_tns_alias_for_all_pdbs
else
	add_or_update_tns_alias_for_pdb $pdb
fi
