--	vim: ts=4:sw=4
set lines 100
col name			for a16	head 'Name'
col network_name	for a16	head 'Network name'
col enabled			for a8	head 'Enabled'
col pdb				for a16	head 'pdb'
select
	name
,	network_name
,	enabled
,	pdb
from
	cdb_services
;
