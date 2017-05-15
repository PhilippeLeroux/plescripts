--	vim: ts=4:sw=4
ttitle 'Corrupted segments' left skip 2;
col	owner			head 'Owner'			for	a8
col segment_name	head 'Segment name'		for a20
col segment_type	head 'Segment type'
col partition_name	head 'Partition'		for a20
col block_id		head 'Block ID'
col file#			head 'File#'
col datafile_name	head 'Datafile name'	for a100
select
	ext.owner
,	ext.segment_name
,	ext.segment_type
,	ext.partition_name
,	ext.block_id
,	err.file#
,	err.datafile_name
from
	cdb_extents	ext
	inner join
		(	select
				dbc.file#
			,	dbc.block#
			,	df.name		datafile_name
			from
				v$database_block_corruption	dbc
			,	v$datafile					df
			where
				dbc.file# = df.file#
		)	err
	on ext.file_id = err.file#
where
	err.block# between ext.block_id and ext.block_id + ext.blocks - 1
;
ttitle clear
