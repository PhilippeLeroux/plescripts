--	vim: ts=4:sw=4
set lines 100
col name			for a24	head 'Name'
col network_name	for a24	head 'Network name'
col pdb				for a24	head 'pdb'
select
	name
,	network_name
,	pdb
from
	cdb_services
order by
	pdb
;
