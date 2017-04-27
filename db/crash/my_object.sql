ttitle 'Avant' skip;
select count(*) from my_objects;
ttitle clear;
drop table my_objects;
create table my_objects as select * from dba_objects;
alter session enable parallel dml;

declare
	max_loops	constant pls_integer := &&1;
	iloop		pls_integer := 0;
begin
	<<loop_insert>>
	loop
		insert /*+ APPEND PARALLEL */ into my_objects
			select * from my_objects
		;
		commit;
		iloop := iloop + 1;
		exit loop_insert when iloop = max_loops;
	end loop;
end;
/

alter session disable parallel dml;

ttitle 'Après' skip;
select count(*) from my_objects;
ttitle clear;
exit
