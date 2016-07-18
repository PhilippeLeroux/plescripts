set serveroutput on
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
procedure main
as
	disks		constant integer := get_number_disks_on_dg( 'DATA' );
	max_latency	constant integer := 10;	-- valeur arbitraire.

--
	latency	integer;
	iops	integer;
	mbps	integer;

begin
	p( 'Calibration for '||disks||' disks' );
	dbms_resource_manager.calibrate_io( disks, max_latency, iops, mbps, latency );

	p('max_iops = ' || iops);
	p('latency  = ' || latency);
	p('max_mbps = ' || mbps);
end main;

begin
	main;
end;
/
