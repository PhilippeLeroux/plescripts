-- vim: ts=4:sw=4

set lines 130
col name			for a26		head 'Name'
col type			for a9		head 'Type'
col display_value	for a40		head 'Value'
select
	name
,	case type
		when 1 then 'bool'
		when 2 then 'str'
		when 3 then 'int'
		when 4 then 'pfile'
		when 5 then 'reserved'
		when 6 then 'big int'
		else 'new '||type
	end type
,	isdefault
,	ismodified
,	isadjusted
,	isdeprecated
,	isbasic
,	display_value
from
	v$parameter
where
	name in ( 'remote_login_passwordfile', 'log_archive_dest_state_2', 'log_archive_dest_2', 'fal_server', 'log_archive_config', 'standby_file_management', 'db_name', 'db_unique_name' )
order by
	num desc
;
