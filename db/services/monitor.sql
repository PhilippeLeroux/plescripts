-- http://docs.oracle.com/database/121/RACAD/hafeats.htm#RACAD7317

SET PAGESIZE 60 COLSEP '|' NUMWIDTH 8 LINESIZE 132 VERIFY OFF FEEDBACK OFF
COLUMN service_name FORMAT A20 TRUNCATED HEADING 'Service'
COLUMN begin_time HEADING 'Begin Time' FORMAT A10
COLUMN end_time HEADING 'End Time' FORMAT A10
COLUMN instance_name HEADING 'Instance' FORMAT A10
COLUMN service_time HEADING 'Service Time|mSec/Call' FORMAT 999999999
COLUMN throughput HEADING 'Calls/sec'FORMAT 99.99 
BREAK ON service_name SKIP 1 
SELECT 
    service_name 
  , TO_CHAR(begin_time, 'HH:MI:SS') begin_time 
  , TO_CHAR(end_time, 'HH:MI:SS') end_time 
  , instance_name 
  , elapsedpercall  service_time
  ,  callspersec  throughput
FROM  
    gv$instance i     
  , gv$active_services s     
  , gv$servicemetric m 
WHERE s.inst_id = m.inst_id  
  AND s.name_hash = m.service_name_hash
  AND i.inst_id = m.inst_id
  AND m.group_id = 10
ORDER BY
   service_name
 , i.inst_id
 , begin_time ;
