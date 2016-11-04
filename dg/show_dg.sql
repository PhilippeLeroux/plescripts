-- vim: ts=4:sw=4

set lines 130 pages 500
break on dg_name on failgroup skip 1
col dg_name for a12
col name for a14
col label for a14
col path for a20
select
    dg.name "dg_name"
,   d.failgroup
,   d.mount_status
,   d.state
,   d.name
,   d.label
,   d.path
from
    v$asm_disk d
,   v$asm_diskgroup dg
where
    d.group_number = dg.group_number
order by
	dg.group_numbeR
,   dg.name
,	d.path
/
