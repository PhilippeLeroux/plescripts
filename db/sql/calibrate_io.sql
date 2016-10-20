--	vim: ts=4:sw=4

set echo off termout off
set lines 120
col col_date new_v fmt_date noprint
select to_char( sysdate, 'HH24:MI:SS' ) col_date from dual;
set termout on feed off
set serveroutput on
set timin on

declare
--
max_latency	constant integer := 100;
--
procedure p( b varchar2 )
as
begin
	dbms_output.put_line( b );
end p;

--
procedure fatal_error(  msg varchar2, errcode pls_integer default -20000 )
as
begin
	raise_application_error( errcode, msg );
end fatal_error;

--
function parameter_value( l_name varchar2 )
	return varchar2
as
	display_value	v$parameter.display_value%type;
begin

	select
		p.display_value
	into
		display_value
	from
		v$parameter p
	where
		p.name = l_name
	;

	return display_value;

exception
	when others then
		p( 'Exception function parameter_value( '||l_name||' )' );
		raise;
end parameter_value;

--
function table_exists( p_table_name varchar2 ) return boolean
as
	l_exist	number := 0;
begin

	select
		count(*)
	into
		l_exist
	from
		dba_tables
	where
		owner = 'SYS'
	and	table_name = upper( p_table_name )
	;

	return l_exist = 1;

end table_exists;

--
procedure prepare_table( trunc_table boolean )
as
	stmt	varchar2(2000) :=
	'create table my_io_calibrate
	(   id                  varchar2(20)
	,   start_time          timestamp(6)
	,   end_time            timestamp(6)
	,   max_iops            number
	,   max_mbps            number
	,   max_pmbps           number
	,   latency             number
	,   num_physical_disks  number
	)';

begin

	if not table_exists( 'my_io_calibrate' )
	then
		p( 'Création de la table my_io_calibrate' );
		execute immediate stmt;
	elsif trunc_table
	then
		p( 'Vide la table my_io_calibrate' );
		execute immediate 'truncate table my_io_calibrate';
	else
		p( 'my_io_calibrate exist.' );
	end if;

end prepare_table;

procedure save_measures
as
	stmt varchar2( 2000 ) :=
	'insert into my_io_calibrate
	select
		sys_context( ''USERENV'', ''DB_UNIQUE_NAME'' )
	,	rsrc_io_c.*
	from
		dba_rsrc_io_calibrate rsrc_io_c';
begin

	execute immediate stmt;

end save_measures;

--
function get_number_disks_on_dg( p_dg_name varchar2 )
	return integer
as
	l_number_disks	integer;
begin

	select
		count(*)
	into
		l_number_disks
	from
		v$asm_disk d
		inner join v$asm_diskgroup dg
		on  d.group_number = dg.group_number
	where
		dg.name = upper( p_dg_name )
	;

	return l_number_disks;

end get_number_disks_on_dg;

--
procedure calibrate( nr_disks number )
as
	latency	integer;
	iops	integer;
	mbps	integer;
begin

	--	Je considère que le nombre de disque est celui dans un DG.
	dbms_resource_manager.calibrate_io( nr_disks, max_latency, iops, mbps, latency );

	save_measures;

end	calibrate;

--
procedure main(	dg_name			varchar2,
				max_loops		number,
				trunc_table		boolean )
as
	timed_stats	constant varchar2(255)	:= parameter_value( 'timed_statistics' );
	disks		constant integer		:= get_number_disks_on_dg( dg_name );
--
	i_loop	number	:= 0;
begin

	if timed_stats != 'TRUE' 
	then
		fatal_error( 'Error timed_statistics == '||timed_stats||' expected TRUE.' );
	end if;

	prepare_table( trunc_table );

	while i_loop < max_loops
	loop
		i_loop := i_loop + 1;
		calibrate( disks );
	end loop;

end main;

begin
	p( 'max_latency = '||max_latency );
	main( dg_name => 'DATA', max_loops => 1, trunc_table => false );
end;
/
set serveroutput off
set timin off

ttitle 'Result :' left
select
	id
,	to_char( start_time, 'YYYY DD HH24:MI' )	"Start"
,	to_char( end_time, 'YYYY DD HH24:MI' )		"End"
,	max_iops									"Max IOPS"
,	max_mbps									"Max mbps"
,	max_pmbps									"Max pmbps Large I/O"
,	latency										"Latency"
,	num_physical_disks							"#disk"
from
	my_io_calibrate
order by
	"Start"
;
ttitle clear

