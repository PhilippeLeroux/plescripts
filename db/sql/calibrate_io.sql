set echo off termout off
set lines 120
col col_date new_v fmt_date noprint
select to_char( sysdate, 'HH24:MI:SS' ) col_date from dual;
set termout on feed off
prompt Start at : &fmt_date
ttitle 'Last measure.' left
select
	to_char( start_time, 'YYYY HH24:MI' )	"Start"
,	to_char( end_time, 'YYYY HH24:MI' )	"End"
,	max_iops							"Max IOPS"
,	max_mbps							"Max mbps"
,	max_pmbps							"Max pmbps  Large I/O"
,	latency								"Latency"
,	num_physical_disks					"#disk"
from
	dba_rsrc_io_calibrate
;
ttitle clear

set serveroutput on
set timin on
declare
--
procedure p( b varchar2 )
as
begin
	dbms_output.put_line( b );
end p;

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
procedure main( print_result boolean )
as
	disks		constant integer := get_number_disks_on_dg( 'DATA' );
	max_latency	constant integer := 10;	-- valeur arbitraire.

--
	latency	integer;
	iops	integer;
	mbps	integer;

begin
	if print_result
	then
		p( 'Calibration for '||disks||' disks' );
	end if;

	dbms_resource_manager.calibrate_io( disks, max_latency, iops, mbps, latency );

	if print_result
	then
		p('max_iops = ' || iops);
		p('latency  = ' || latency);
		p('max_mbps = ' || mbps);
	end if;
end main;

begin
	main( print_result => false );
end;
/

ttitle 'Result :' left
select
	to_char( start_time, 'YYYY HH24:MI' )	"Start"
,	to_char( end_time, 'YYYY HH24:MI' )	"End"
,	max_iops							"Max IOPS"
,	max_mbps							"Max mbps"
,	max_pmbps							"max pmbps Large I/O"
,	latency								"Latency"
,	num_physical_disks					"#disk"
from
	dba_rsrc_io_calibrate
;
ttitle clear

