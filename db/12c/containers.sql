set lines 150
select
	c.con_id
,	c.name
,	c.open_mode
,	to_char( c.open_time, 'YY/MM/DD HH24:MI' ) "Open time"
,	round( c.total_size / 1024 / 1024 / 1024, 0 ) "Total size"
,	c.recovery_status
,	c.restricted
from
	v$containers c
	inner join dba_pdbs pdbs
		on c.con_id = pdbs.pdb_id
/
