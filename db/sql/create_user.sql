-- vim: ts=4:sw=4
set ver off
define username=ple
define tbs='&username.tbs'

set serveroutput on size unlimited
declare
LN constant char(1) := chr(10);

--	Constantes pour la fonction exec :
on_error_raise		constant pls_integer := 1;
on_error_continue	constant pls_integer := 2;

--
procedure p( b varchar2 ) as
begin
	dbms_output.put_line( b );
end p;

--
function exist_tbs( tbs_name varchar2 ) return boolean as
	foo dba_tablespaces.tablespace_name%type;
begin
	select
		tablespace_name
	into
		foo
	from
		dba_tablespaces
	where
		tablespace_name=upper( tbs_name )
	;

	return true;

exception
	when no_data_found	then return false;
	when others			then raise;
end exist_tbs;

--
procedure exec( cmd varchar2, on_error pls_integer default on_error_raise ) as
begin
	p( '> '||cmd||';' );
	execute immediate cmd;
	p( '-- success.'||LN );
exception
	when others then
		if on_error = on_error_raise then
			p( '-- Failed : '||sqlerrm||LN );
			raise;
		else
			p( '-- Warning : '||sqlerrm||LN );
		end if;
end exec;

begin
	exec( 'drop user &username cascade', on_error_continue );
	exec( 'drop tablespace pletbs including contents and datafiles', on_error_continue );

	if not exist_tbs( '&tbs' ) then
		exec( 'create bigfile tablespace &tbs' );
	end if;

	exec( 'alter profile default limit password_life_time unlimited' );
	exec( 'create user &username identified by &username default tablespace &tbs' );
	exec( 'grant create session, create table to &username' );
	exec( 'alter user &username quota unlimited on  &tbs' );
	p( 'Grant to used dbms_xplan' );
	exec( 'grant select on v_$session					to &username' );
	exec( 'grant select on v_$sql_plan					to &username' );
	exec( 'grant select on v_$sql_plan_statistics_all	to &username' );
	exec( 'grant select on v_$sql						to &username' );
end;
/

prompt
@create_role_plustrace.sql
