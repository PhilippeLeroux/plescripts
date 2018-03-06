-- vim: ts=4:sw=4
set lines 130
col	pdb_name			for	a12	head "PDB name"
col	refresh_mode				head "Mode"
col	refresh_interval			head "Interval (mn)"
select
	pdb_name
,	refresh_mode
,	refresh_interval
from
	cdb_pdbs
where
	pdb_name not like '%SEED'
order by
	refresh_mode
;
