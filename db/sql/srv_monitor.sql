-- vim: ts=4:sw=4
-- http://docs.oracle.com/database/121/RACAD/hafeats.htm#RACAD7317

set pagesize 60 colsep '|' numwidth 8 linesize 132 verify off feedback off
column service_name format a20 truncated heading 'Service'
column begin_time heading 'Begin Time' format a10
column end_time heading 'End Time' format a10
column instance_name heading 'Instance' format a10
column service_time heading 'Service Time|mSec/Call' format 999999999
column throughput heading 'Calls/sec'	format 99.99
break on service_name skip 1
select
    service_name
  , to_char(begin_time, 'HH:MI:SS') begin_time
  , to_char(end_time, 'HH:MI:SS') end_time
  , instance_name
  , elapsedpercall  service_time
  ,  callspersec  throughput
from
    gv$instance i
  , gv$active_services s
  , gv$servicemetric m
where s.inst_id = m.inst_id
  and s.name_hash = m.service_name_hash
  and i.inst_id = m.inst_id
  and m.group_id = 10
order by
   service_name
 , i.inst_id
 , begin_time ;
