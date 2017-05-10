-- vim: ts=4:sw=4
set serveroutput on
set timin on
begin
	dbms_output.put_line('dbms_feature_usage_internal.exec_db_usage_sampling(sysdate);');
	dbms_feature_usage_internal.exec_db_usage_sampling(sysdate);
	commit;
end;
/
