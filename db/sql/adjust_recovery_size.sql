-- vim: ts=4:sw=4

--	Je pars du principe que sur un serveur il n'y a qu'un seul CDB, donc
--	db_recovery_file_dest_size aura 80% de la taille de la FRA.

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

--
function get_dg_size_gb( dg_name varchar2 )
	return number
as
	l_dg_size_gb	number;
begin

	select
		round( total_mb/1024 )
	into
		l_dg_size_gb
	from
		v$asm_diskgroup
	where
		name = upper( dg_name )
	;

	p( 'Size disk group '||dg_name||' = '||l_dg_size_gb||'Gb' );

	return l_dg_size_gb;

end get_dg_size_gb;

--
procedure main( dg_fra_name varchar2 ) as
	fra_size_gb	constant number := round( get_dg_size_gb( dg_fra_name ) * 0.8 );
begin
	p( 'Recovery size 80% of '||dg_fra_name );
	exec( 'alter system set db_recovery_file_dest_size='||fra_size_gb||'G scope=both sid=''*''' );
end main;

--
begin
	main( 'FRA' );
end;
/
