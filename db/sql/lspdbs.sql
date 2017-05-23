-- vim: ts=4:sw=4
set lines 130
col	instance_name	for	a10		head "Instance"
col	name			for	a12		head "PDB name"
col	open_mode					head "Open mode"
col recovery_status				head "Reco status"
select
    i.instance_name
,   c.name
,   c.open_mode
,	to_char( c.open_time, 'YY/MM/DD HH24:MI' ) "Open time"
,	round( c.total_size / 1024 / 1024, 0 ) "Size (Mb)"
,	c.recovery_status
,	nvl(pss.state,'NOT SAVED') "State"
from
    gv$containers c
    inner join gv$instance i
        on  c.inst_id = i.inst_id
	left join dba_pdb_saved_states pss
		on	c.con_uid = pss.con_uid
		and	c.guid = pss.guid
order by
    c.name
,   i.instance_name
/
