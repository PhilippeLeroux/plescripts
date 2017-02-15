#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=name -pdb=name"

script_banner $ME $*

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

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

ORACLE_SID=$(~/plescripts/db/get_active_instance.sh)
info "Load env for ORACLE_SID=$ORACLE_SID"
ORAENV_ASK=NO . oraenv
LN

function ddl_create_pdb_samples
{
	#	Sur un dataguard le PDB doit être ouvert, pour pouvoir être cloné
	#	le PDB doit être en lecture. Il n'y aura pas de service pour ce PDB
	#	donc on sauvegarde son état.
	set_sql_cmd "whenever sqlerror exit 1;"
	set_sql_cmd "create pluggable database pdb_samples from $pdb;"
	set_sql_cmd "alter pluggable database pdb_samples open read write instances=all;"
	set_sql_cmd "alter pluggable database pdb_samples close instances=all;"
	set_sql_cmd "alter pluggable database pdb_samples open read only instances=all;"
	set_sql_cmd "alter pluggable database pdb_samples save state instances=all;"
}

sqlplus_cmd "$(ddl_create_pdb_samples)"
