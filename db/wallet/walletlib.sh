# vim: ts=4:sw=4

typeset -r wallet_path=${ORA_WALLET-$ORACLE_HOME/oracle/wallet}

#*> return 0 if wallet on CFS else return 1
function wallet_store_on_cfs
{
	typeset -r test_file=$wallet_path/is_cfs
	touch $test_file
	ssh ${gi_node_list[0]} test -f $test_file
	typeset is_cfs=$?
	rm $test_file
	return $is_cfs
}
