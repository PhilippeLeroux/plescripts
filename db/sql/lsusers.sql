--	vim: ts=4:sw=4

set lines 120
col	username				for a26	head "User name"
col	user_id							head "Used ID"
col default_tablespace		for a20 head "(*)tablespace"
col temporary_tablespace	for a20	head "Temporary"
col	account_status			for a10	head "Status"

select
	username
,	user_id
,	default_tablespace
,	temporary_tablespace
,	account_status
,	to_char( last_login, 'YY/MM/DD HH24:MI' ) "Last login"
from
	dba_users
where
	oracle_maintained = 'N'
;
