set feed off
accept the_user prompt 'Enable su on user : ' 
alter user &the_user grant connect through su;

prompt
prompt to connect with user &the_user : conn su[&the_user]/su@<alias tns>
prompt
