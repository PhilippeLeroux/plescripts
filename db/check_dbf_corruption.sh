#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset		db=undef
typeset		pdb=undef

typeset -r str_usage=\
"Usage : $ME
\t-db=name
\t-pdb=name|cdb"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-pdb=*)
			pdb=$(to_lower ${1##*=})
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

must_be_user oracle

exit_if_param_undef db	"$str_usage"
exit_if_param_undef pdb	"$str_usage"

typeset	-r	log_dir="$ORACLE_BASE/admin/$ORACLE_SID/log/$(date +%Y-%m-%d)"
if [ ! -d "$log_dir" ]
then
	exec_cmd "mkdir $log_dir"
	LN
fi

if [ $pdb == cdb ]
then
	load_oraenv_for $(to_upper $db)
	typeset	-r	connect_str="sys/$oracle_password as sysdba"
	typeset	-r	log_name="$log_dir/dbv_on_$db.log"
else
	typeset	-r	connect_str="sys/$oracle_password@sys$pdb as sysdba"
	typeset	-r	log_name="$log_dir/dbv_on_$pdb.log"
fi

exec_cmd "rm -f '$log_name'"
LN

info "Create script /tmp/dbv.sql"
fake_exec_cmd "sqlplus -s $connect_str<<EO_SQL"
sqlplus -s $connect_str<<EO_SQL > /tmp/dbv.sh
set feed off
set heading off
set trim on
set lines 160
spool $HOME/plescripts/tmp/dbv.sh
prompt #!/bin/bash
prompt
prompt set -x
select
'dbv file='''||file_name||''' 2>>$log_name'
from
	dba_data_files
/
prompt
EO_SQL
LN

exec_cmd "chmod ugo+rwx /tmp/dbv.sh"
LN

if command_exists crsctl
then
	exec_cmd "sudo -iu grid /tmp/dbv.sh"
	LN
else
	exec_cmd "/tmp/dbv.sh"
	LN
fi

info "Check log $log_name"
exec_cmd "grep -E 'Failing|Corrupt' '$log_name'"
LN
