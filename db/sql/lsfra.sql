set lines 100
col name for a20
select
	name
,	round(space_limit / 1024 / 1024 / 1024) "Size Gb"
,	round(space_used  / 1024 / 1024 / 1024) "Used Gb"
,	round(space_used/space_limit*100,2) "%Used"
from
	v$recovery_file_dest
order by
	name
/
