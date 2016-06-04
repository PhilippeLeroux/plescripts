create diskgroup ACFS normal redundancy
failgroup fg1 disk
	'ORCL:R01_LUN_08'
,	'ORCL:R01_LUN_09'
,	'ORCL:R01_LUN_10'
failgroup fg2 disk
	'ORCL:R02_LUN_08'
,	'ORCL:R02_LUN_09'
,	'ORCL:R02_LUN_10'
attribute
	'content.type' = 'data'
,	'compatible.asm' = '11.2.0.4.0'
;
