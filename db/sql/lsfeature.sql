-- vim: ts=4:sw=4
col name			for A40						head 'Name'
col detected_usages	for 999G999					head '#Usages'
col aux_count		for 999G999G999G999G999		head '#aux'

select
	name
,	detected_usages
,	aux_count
,	currently_used		"Used"
,	first_usage_date	"First"
,	last_usage_date		"Last"
from
	dba_feature_usage_statistics
where
	detected_usages != 0
order by
	last_usage_date
,	detected_usages
;
