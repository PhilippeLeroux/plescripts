select
	d.name
,	d.failgroup
from
	v$asm_disk d
	inner join v$asm_diskgroup dg
	on	d.group_number = dg.group_number
where
	dg.name = 'DATA'
;

