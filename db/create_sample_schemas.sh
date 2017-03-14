#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset db=undef
typeset pdb=undef
typeset service=localhost:1521

typeset -r str_usage=\
"Usage : $ME
	-db=name
	-pdb=name
	[-service=$service] used localhost:1521 if no service exists.
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

script_banner $ME $*

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

exit_if_ORACLE_SID_not_defined

exit_if_database_not_exists $db
typeset	-r	orcl_release=$($ORACLE_HOME/OPatch/opatch lsinventory	|\
									grep "Oracle Database 12c"		|\
									awk '{ print $4 }' | cut -d. -f1-4)

if [ "$service" == "localhost:1521" ]
then
	service_param=$service
	service="$service/$pdb"
else
	service=$(mk_oci_service $pdb)
	service_param=$service
	if test_if_exists_cmd olsnodes
	then
		exit_if_service_not_running $db $service
	fi
fi

typeset -r sample_dir="$HOME/db-sample-schemas-$orcl_release"

info -n "Exists '$sample_dir' "
if [ ! -d "$sample_dir" ]
then
	info -f "[$KO]"
	LN
	exit 1
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

exec_cmd "perl -p -i.bak -e 's#__SUB__CWD__#'$(pwd)'#g' *.sql */*.sql */*.dat"
LN

info "Execute mksample :"
fake_exec_cmd "sqlplus system/$oracle_password@$service @mksample ...."
sqlplus system/$oracle_password@$service<<OE_CMD
@mksample $oracle_password $oracle_password hr oe pm ix sh bi users temp $sample_dir/logs/ $service
OE_CMD
LN

info "Unlock sample schemas."
exec_cmd ~/plescripts/db/sample_schemas_unlock_accounts.sh	\
											-db=$db			\
											-pdb=$pdb		\
											-service=$service_param
LN

script_stop $ME
