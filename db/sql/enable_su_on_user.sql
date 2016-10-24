set feed off
accept the_user prompt 'Enable su on user : ' 
alter user &the_user grant connect through su;
