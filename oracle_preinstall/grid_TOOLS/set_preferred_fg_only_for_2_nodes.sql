set lines 130 pages 90
set serveroutput on size unlimited
declare
--
procedure p( b varchar2 )
as
begin
	dbms_output.put_line( b );
end p;

--
function get_instance_name( p_instance_number pls_integer )
	return varchar2
as
	stmt constant varchar2( 2000 ) := 'select instance_name from gv$instance where instance_number = :instance_number';
	l_instance_name	varchar2( 30 ); --instance%intance_name;
begin

	execute immediate stmt
				into	l_instance_name
				using	p_instance_number
			;

	return l_instance_name;

end get_instance_name;

--
procedure apply_asm_pref( inst_no pls_integer, inst_name varchar2 )
as
	dg_data	constant varchar2(100) := '''DATA.FG'||inst_no||'''';
	dg_fra	constant varchar2(100) := '''FRA.FG'||inst_no||'''';
	dg_acfs	constant varchar2(100) := '''ACFS.FG'||inst_no||'''';

	stmt varchar2(1000) := 'alter system set asm_preferred_read_failure_groups='
							||dg_data||','||dg_fra||','||dg_acfs
							||' scope=both sid='''||inst_name||'''';
begin
	p( '>'||stmt );
	execute immediate stmt;
end apply_asm_pref;

--
procedure main
as
	instance1 constant varchar2(30) := get_instance_name( 1 );
	instance2 constant varchar2(30) := get_instance_name( 2 );

begin
	apply_asm_pref( 1, instance1 );
	apply_asm_pref( 2, instance2 );
end main;

begin
	main;
end;
/
