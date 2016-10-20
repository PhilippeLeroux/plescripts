--	vim: ts=4:sw=4
col	host	for a16
col	inst	for a16
col	service	for a16
select
	sys_context( 'USERENV', 'SERVER_HOST' )		"Host"
,	sys_context( 'USERENV', 'INSTANCE_NAME' )	"Inst"
,	sys_context( 'USERENV', 'SERVICE_NAME' )	"Service"
from
	dual
;
