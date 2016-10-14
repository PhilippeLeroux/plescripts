declare
procedure metadata_param( name varchar2, value boolean )
as
begin
	dbms_metadata.set_transform_param( dbms_metadata.session_transform, name, value );
end metadata_param;

begin
	metadata_param( 'SQLTERMINATOR', true );

	metadata_param ( 'PRETTY', true );

	metadata_param( 'SEGMENT_ATTRIBUTES', false );

	metadata_param( 'STORAGE', false );
end;
/

set lines 150
set pages 0
set long 100000
set longchunksize 100000

select dbms_metadata.get_ddl('TABLE','MY_IO_CALIBRALE') from dual;
