#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset db=undef
typeset pdb=undef
typeset service=auto
typeset	tablespace_name=demos

typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
	[-tablespace_name=$tablespace_name]
	[-service=$service] if no service used localhost:1521
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

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-tablespace_name=*)
			tablespace_name=${1##*=}
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

script_start

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_ORACLE_SID_not_defined

exit_if_database_not_exists $db
typeset	-r	orcl_version=$(read_orcl_version)

case "$service" in
	"localhost:1521")
		service_param=$service
		service="$service/$pdb"
		;;
	auto)
		service=$(mk_oci_service $pdb)
		service_param=$service
		exit_if_service_not_running $db $service
		;;
	*)
		exit_if_service_not_running $db $service
		;;
esac

if [ ${orcl_version%.*.*.*} == 12 ]
then
	typeset	-r	fake_orcl_version=$orcl_version
else
	typeset	-r	fake_orcl_version=12.2.0.1
fi

typeset -r sample_dir="$HOME/db-sample-schemas-$fake_orcl_version"

info -n "Exists '$sample_dir' "
if [ ! -d "$sample_dir" ]
then
	info -f "[$KO]"
	LN
	info "From $client_hostname execute :"
	info "cd ~/plescripts/database_servers"
	info "./install_sample_schema.sh -db=$db"
	LN
	exit 0
else
	info -f "[$OK]"
	LN
fi

fake_exec_cmd cd $sample_dir
cd $sample_dir || exit 1
LN

if [ ! -d log ]
then
	exec_cmd mkdir log
	LN
fi

line_separator
info "Create tablespace $tablespace_name"
sqlplus_cmd_with sys/$oracle_password@"$service" as sysdba	\
					"$(set_sql_cmd "create tablespace $tablespace_name;")"
LN

line_separator
exec_cmd "perl -p -i.bak -e 's#__SUB__CWD__#'$(pwd)'#g' *.sql */*.sql */*.dat"
LN

line_separator
info "Execute mksample :"
sqlplus_cmd "$(set_sql_cmd @mksample $oracle_password $oracle_password hr oe pm ix sh bi $tablespace_name temp $sample_dir/logs/ $service)"
LN

line_separator
info "Unlock sample schemas."
exec_cmd ~/plescripts/db/sample_schemas_unlock_accounts.sh	\
											-db=$db			\
											-pdb=$pdb		\
											-service=$service_param
LN

script_stop $ME $db
