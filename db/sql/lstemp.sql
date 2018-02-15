-- vim: ts=4:sw=4

--	Affiche les PDBs et leurs tablespaces associées.

set pages 80

col	name	head "PDB name"	for a9

break on name skip 2

select
	c.name
,	file_id
,	cdf.tablespace_name
,	round( cdf.bytes / 1024 / 1024 ) Mb
,	cdf.status
,	cdf.file_name
from
	cdb_temp_files cdf
	inner join v$containers c
		on cdf.con_id = c.con_id
order by
	c.name
;

col name	clear
