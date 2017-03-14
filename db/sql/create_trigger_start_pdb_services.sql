-- vim: ts=4:sw=4
create or replace
trigger start_pdb_services after startup on database
declare
	db_role			varchar(255);
	db_open_mode	varchar(255);
	oci_srv			varchar(20);
	java_srv		varchar(20);
begin

	select
		database_role
	,	open_mode
	into
		db_role
	,	db_open_mode
	from
		v$database
	;

	if db_role = 'PRIMARY'
	then
		oci_srv  := '%_oci';
		java_srv := '%_java';
	elsif db_role = 'PHYSICAL STANDBY' and db_open_mode = 'READ ONLY WITH APPLY'
	then
		oci_srv  := '%_stby_oci';
		java_srv := '%_stby_java';
	end if;

	if oci_srv is not null
	then
		for s in (	select name from dba_services
					where network_name like oci_srv or network_name like java_srv )
		loop
			dbms_service.start_service( s.name );
		end loop;
	end if;
	
end start_pdb_services;
/
