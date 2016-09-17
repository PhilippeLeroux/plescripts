set lines 100
col spid	for	a8
col stid	for a8
col	program	for a35
col pga_u_a	for	a16
select
	spid
,	stid
,	program
,	round(pga_used_mem/1024/1024,2)||' / '||round(pga_alloc_mem/1024/1024,2) pga_u_a
from
	v$process
order by
	pga_alloc_mem
;
