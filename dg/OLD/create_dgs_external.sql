drop diskgroup DATA;
create diskgroup DATA external redundancy
disk
	'ORCL:SRVZZZ03'
,	'ORCL:SRVZZZ04'
,	'ORCL:SRVZZZ05'
attribute
	'compatible.asm' = '12.1.0.0'
,	'compatible.rdbms' = '12.1.0.0'
;

drop diskgroup FRA;
create diskgroup FRA external redundancy
disk
    'ORCL:SRVZZZ06'
,   'ORCL:SRVZZZ07'
,   'ORCL:SRVZZZ08'
attribute
	'compatible.asm' = '12.1.0.0.0'
,   'compatible.rdbms' = '12.1.0.0.0'
;

