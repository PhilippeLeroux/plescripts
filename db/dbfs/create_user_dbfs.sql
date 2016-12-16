define tbs_name=&1
define user=&2
define pass=&3

prompt create tablespace &tbs_name;
create tablespace &tbs_name;

prompt create user &user
create user &user identified by &pass
	default tablespace &tbs_name
	temporary tablespace temp
	quota unlimited on &tbs_name
;

prompt grant create session, resource, create view, dbfs_role to &user;
grant create session, resource, create view, dbfs_role to &user;


