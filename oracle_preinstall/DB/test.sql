--asm_preferred_read_failure_groups
select
	instance_name
from
	v$instance
where
	instance_number=1
;
