create diskgroup DATA normal redundancy
failgroup fg1 disk
	'ORCL:R01_LUN_02'
,	'ORCL:R01_LUN_03'
,	'ORCL:R01_LUN_04'
failgroup fg2 disk
	'ORCL:R02_LUN_02'
,	'ORCL:R02_LUN_03'
,	'ORCL:R02_LUN_04'
attribute
	'content.type' = 'data'
,	'compatible.asm' = '11.2.0.4.0'
;

create diskgroup FRA normal redundancy
failgroup fg1 disk
	'ORCL:R01_LUN_05'
,	'ORCL:R01_LUN_06'
,	'ORCL:R01_LUN_07'
failgroup fg2 disk
	'ORCL:R02_LUN_05'
,	'ORCL:R02_LUN_06'
,	'ORCL:R02_LUN_07'
attribute
	'content.type' = 'recovery'
,	'compatible.asm' = '11.2.0.4.0'
;
