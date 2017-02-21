--	vim: ts=4:sw=4
set lines 100
ttitle center "PGA usage (Mb)" skip
col spid			for	a8		head 'spid'
col stid			for a8		head 'stid'
col	program			for a38		head 'Program'
col	execution_type				head 'Type'	
col	pga_used		for 99		head 'PGA used'
col	pga_alloc		for 99		head 'PGA alloc'
select
	spid
,	stid
,	program
,	execution_type
,	round(pga_used_mem/1024/1024,2)	pga_used
,	round(pga_alloc_mem/1024/1024,2) pga_alloc
from
	v$process
order by
	pga_alloc_mem
;
