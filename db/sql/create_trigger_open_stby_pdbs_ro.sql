-- vim: ts=4:sw=4
create or replace
trigger open_stby_pdbs_ro after startup on database
begin
	if sys_context('USERENV', 'DATABASE_ROLE') = 'PHYSICAL STANDBY'
	then
		execute immediate 'alter pluggable database all open';
	end if;
end open_stby_pdbs_ro;
/
