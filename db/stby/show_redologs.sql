set lines 130 pages 40
col member for a45
select
	lf.group#
,	lf.status
,	lf.type
,	lf.member
,	lf.con_id
from
	v$logfile lf
order by
	lf.type
,	lf.group#
/
