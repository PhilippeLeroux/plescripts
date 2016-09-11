select
	dest_id
,	fal
,	sequence#
,	status
,	applied
from
	v$archived_log
order by
	dest_id
,	sequence#
;
