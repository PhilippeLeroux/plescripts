-- vim: ts=4:sw=4
set feed off
set heading off
set trim on
spool $HOME/plescripts/tmp/dbv.sh
select
	'dbv file='''||file_name||''''
from
	dba_data_files
/
spool off
prompt sugrid bash plescripts/tmp/dbv.sh
