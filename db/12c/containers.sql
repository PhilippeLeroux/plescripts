set lines 150
col	instance_name	for	a10		head "Instance"
col	name			for	a10		head "PDB name"
col	open_mode					head "Open mode"
select
    i.instance_name
,   c.name
,   c.open_mode
,	to_char( c.open_time, 'YY/MM/DD HH24:MI' ) "Open time"
,	round( c.total_size / 1024 / 1024 / 1024, 0 ) "Total size"
,	c.recovery_status
,	c.restricted
from
    gv$containers c
    inner join gv$instance i
        on  c.inst_id = i.inst_id
where
	c.name != 'PDB$SEED'
order by
    c.name
,   i.instance_name
/
