alter system reset memory_target scope=spfile sid='*';
alter system set sga_target=512M scope=spfile sid='*';
alter system set pga_aggregate_target=256M scope=spfile sid='*';
