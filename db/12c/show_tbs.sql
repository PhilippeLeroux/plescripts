-- vim: ts=4:sw=4
select
	tablespace_name				"Name"
,	initial_extent				"Init ext"
,	allocation_type				"Alloc"
,	segment_space_management	"Space mngmt"
,	bigfile						"Big File"
from
	dba_tablespaces
;
