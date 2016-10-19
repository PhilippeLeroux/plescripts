--
-- Copyright (c) 1988, 2005, Oracle.  All Rights Reserved.
--
-- NAME
--   glogin.sql
--
-- DESCRIPTION
--   SQL*Plus global login "site profile" file
--
--   Add any SQL*Plus commands here that are to be executed when a
--   user starts SQL*Plus, or uses the SQL*Plus CONNECT command.
--
-- USAGE
--   This script is automatically run
--

set termout off		-- no empty lines printed.
set feedback off

alter session set nls_date_format = 'YY/MM/DD HH24:MI';

define y='idle'
col x new_value y noprint
select
	lower(user || '@' || sys_context('userenv', 'con_name')) X
from
	dual
;
set sqlprompt '&Y> '

set pagesize 24
set linesize 120
set numformat 999,999,999

set feedback on
set termout on
