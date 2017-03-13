-- vim: ts=4:sw=4
create or replace
trigger start_pdb_services after startup on database
declare
	db_role varchar(255);
	oci_srv varchar(20);
	java_srv varchar(20);
begin

	select
		database_role
	into
		db_role
	from
		v$database
	;

	if db_role = 'PRIMARY'
	then
		oci_srv := '%_oci';
		java_srv := '%_java';
	else
		oci_srv := '%_stby_oci';
		java_srv := '%_stby_java';
	end if;
	
	for s in (	select name from dba_services
				where network_name like oci_srv or network_name like java_srv )
	loop
		dbms_service.start_service( s.name );
	end loop;
	
end start_pdb_services;
/
