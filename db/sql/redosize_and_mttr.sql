ttitle 'Advices redo log size and mttr' skip;
select
	inst_id						"#inst"
,	optimal_logfile_size		"Optimal logfile size"
,	target_mttr					"Target MTTR"
,	estimated_mttr				"Estimated MTTR"
,	recovery_estimated_ios		"Recovery estimated IO/s"
from
	gv$instance_recovery
;
ttitle off
