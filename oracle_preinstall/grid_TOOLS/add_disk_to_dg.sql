alter diskgroup data add
failgroup fg1 disk
	'ORCL:R01_LUN_11'
,	'ORCL:R01_LUN_12'
failgroup fg2 disk
	'ORCL:R02_LUN_11'
,	'ORCL:R02_LUN_12'
rebalance power 10 nowait
;
exit

alter diskgroup fra
drop disk
	R01_LUN_11
,	R01_LUN_12
,	R02_LUN_11
,	R02_LUN_12
rebalance power 10 nowait
;

