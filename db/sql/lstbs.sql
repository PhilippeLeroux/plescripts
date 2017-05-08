-- vim: ts=4:sw=4
select
	tablespace_name				"Name"
,	initial_extent				"Init ext"
,	allocation_type				"Alloc"
,	extent_management			"Ext mngmt"
,	segment_space_management	"Space mngmt"
,	bigfile						"Big File"
,	logging						"Logging"
,	force_logging				"Force"
,	shared						"Shared"
from
	cdb_tablespaces
;
