set lines 150 pages 90
col dg_name		for a8		head "DG name"
col attr_name	for a16		head "Attr name"
col value					head "Attr value"
col	read_only				head "RO"
break on dg_name skip 1;
select
    dg.name                         dg_name
,   attr.name                       attr_name
,   attr.value
,   attr.read_only
from
    v$asm_attribute attr
    inner join v$asm_diskgroup dg
        on attr.group_number = dg.group_number
where
    attr.name in ('au_size', 'sector_size', 'compatible.asm', 'compatible.rdbms', 'compatible.advm','disk_repair_time')
order by
	dg.name
,	attr.read_only
/
