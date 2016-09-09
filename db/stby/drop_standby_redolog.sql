set serveroutput on size unlimited
declare
--
procedure p( b varchar2 )
as
begin
	dbms_output.put_line( b );
end p;

--
procedure main
as
begin
	for line in ( select distinct group# from v$logfile where type = 'STANDBY' )
	loop
		p( 'drop standby logfile group '||line.group# );
		execute immediate 'alter database drop standby logfile group '||line.group#;
	end loop;
end main;

begin
	main;
end;
/
