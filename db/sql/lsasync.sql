--	vim: ts=4:sw=4

set lines 130
set pages 90

select
	asynch_io
,	name
from
	v$datafile f
,	v$iostat_file i
where
	 f.file#=i.file_no
and	filetype_name='Data File'
/
