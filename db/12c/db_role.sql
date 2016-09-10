set lines 130
col	name			for a10		head 'DB name'
col	open_mode		for a10		head 'Open mode'
col	database_role				head 'DB role'
col	protection_mode				head 'Protection mode'
col	protection_level			head 'Protection level'
col	dataguard_broker			head 'Broker'
select
	d.name
,	d.open_mode
,	d.database_role
,	d.protection_mode
,	d.protection_level
,	d.dataguard_broker
,	d.cdb
from
	v$database d
/
