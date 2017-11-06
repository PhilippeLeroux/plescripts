-- vim: ts=4:sw=4

-- -
-- Must be executed from PDB or CDB
-- -

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

prompt
prompt Execute
prompt sugrid bash plescripts/tmp/dbv.sh
prompt or
prompt bash ~/plescripts/tmp/dbv.sh
