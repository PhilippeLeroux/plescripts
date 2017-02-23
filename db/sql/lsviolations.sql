--	vim: ts=4:sw=4
--	sqldevelpper pas sqlplus
set lines 100
select
	*
from
	pdb_plug_in_violations
where
	status != 'RESOLVED'
;
