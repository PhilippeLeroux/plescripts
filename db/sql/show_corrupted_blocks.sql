select
	df.file#
,	df.name
,	blk_err.*
from
	v$database_block_corruption blk_err
,	v$datafile df
where
	blk_err.file# = df.file#
;

select file#, name from v$datafile;

blockrecover datafile 1 block 61441;

select
	owner
,	segment_name
,	segment_type
,	partition_name
from
	dba_extents 
where
	file_id=9
and
	34844 between block_id and block_id+blocks-1;
