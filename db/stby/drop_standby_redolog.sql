set lines 130 pages 80
select
	distinct 'alter database drop standby logfile group '||group#||';'
from
	v$logfile
where
	type = 'STANDBY'
;
