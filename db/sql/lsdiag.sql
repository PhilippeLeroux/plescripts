-- vim: ts=4:sw=4

set lines 120
col name for a24
col value for a90
select
	name
,	value
from
	v$diag_info
;
