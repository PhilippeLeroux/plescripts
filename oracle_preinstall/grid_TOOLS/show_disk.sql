set lines 130 pages 500
col dg_name for a12
col name for a12
col label for a12
col path for a20
select
	d.group_number
,	d.mount_status
,   d.state
,   d.failgroup
,   d.name
,   d.label
,   d.path
from
    v$asm_disk d
where
	d.group_number = 0	-- candidat
order by
    name
/
