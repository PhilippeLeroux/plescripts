-- vim: ts=4:sw=4
set lines 130
col	owner		for a10		head 'Owner'
col	db_link		for	a26		head 'DB link'
col	username	for a10		head 'Username'
col	host		for a26		head 'Host'
select
	owner
,	db_link
,	username
,	host
from
	all_db_links
;
