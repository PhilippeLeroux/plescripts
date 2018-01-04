-- vim: ts=4:sw=4
create or replace
trigger start_pdb_services after startup on pluggable database
begin
--	Le trigger doit être crée sur le PDB.

	if sys_context('USERENV', 'DATABASE_ROLE') = 'PRIMARY'
	then
		for s in (	select name from dba_services
					where
						network_name not like '%_stby_%'
					and	(	network_name like '%_oci'
						or	network_name like '%_java'
						)
				)
		loop
			dbms_service.start_service( s.name );
		end loop;
	elsif sys_context('USERENV', 'DATABASE_ROLE') = 'PHYSICAL STANDBY'
	then
		for s in (	select name from dba_services
					where network_name like '%_stby_oci' or network_name like '%_stby_java' )
		loop
			dbms_service.start_service( s.name );
		end loop;
	end if;

end start_pdb_services;
/
